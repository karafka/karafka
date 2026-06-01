# frozen_string_literal: true

require_relative "client"

module Karafka
  module Instrumentation
    module Vendors
      # Namespace for New Relic instrumentation
      module NewRelic
        # Listener that ships Karafka metrics to New Relic via NewRelic::Agent.record_metric.
        #
        # @note Requires the `newrelic_rpm` gem with a configured agent.
        #
        # @note New Relic custom metrics do not support tags. Context (consumer group, topic,
        #   partition, broker) is encoded directly in the metric name.
        #
        # @example Basic setup
        #   require "karafka/instrumentation/vendors/new_relic/metrics_listener"
        #
        #   Karafka.monitor.subscribe(
        #     Karafka::Instrumentation::Vendors::NewRelic::MetricsListener.new
        #   )
        #
        # @example Custom namespace
        #   Karafka.monitor.subscribe(
        #     Karafka::Instrumentation::Vendors::NewRelic::MetricsListener.new do |config|
        #       config.namespace = "my_app"
        #     end
        #   )
        #
        # Metrics are published under Custom/{namespace}/... and can be queried in New Relic
        # via the metric timeslice API or used in custom dashboard widgets.
        class MetricsListener
          include ::Karafka::Core::Configurable
          extend Forwardable

          def_delegators :config, :client, :rd_kafka_metrics, :namespace

          # Value object for storing a single rdkafka metric publishing details
          RdKafkaMetric = Struct.new(:scope, :name, :key_location)

          # Namespace prefix for all published metrics
          setting :namespace, default: "karafka"

          # Client used to publish metrics. Defaults to a wrapper around NewRelic::Agent.
          setting :client, default: Client.new

          # rdkafka metrics published on each statistics.emitted event.
          # Unlike tag-based systems, topic/partition/broker context is embedded in the metric name.
          # Note: metrics with `_d` suffix are Karafka-computed deltas, not raw rdkafka values.
          setting :rd_kafka_metrics, default: [
            # Client-level
            RdKafkaMetric.new(:root, "messages.consumed", "rxmsgs_d"),
            RdKafkaMetric.new(:root, "messages.consumed.bytes", "rxmsg_bytes"),

            # Broker-level (published as Custom/{ns}/broker.{name}/{metric_name})
            RdKafkaMetric.new(:brokers, "consume.attempts", "txretries_d"),
            RdKafkaMetric.new(:brokers, "consume.errors", "txerrs_d"),
            RdKafkaMetric.new(:brokers, "receive.errors", "rxerrs_d"),
            RdKafkaMetric.new(:brokers, "connection.connects", "connects_d"),
            RdKafkaMetric.new(:brokers, "connection.disconnects", "disconnects_d"),
            RdKafkaMetric.new(:brokers, "network.latency.avg", %w[rtt avg]),
            RdKafkaMetric.new(:brokers, "network.latency.p95", %w[rtt p95]),
            RdKafkaMetric.new(:brokers, "network.latency.p99", %w[rtt p99]),

            # Topic/partition-level (published as Custom/{ns}/{metric_name}/{topic}/{partition})
            RdKafkaMetric.new(:topics, "consumer.lags", "consumer_lag_stored"),
            RdKafkaMetric.new(:topics, "consumer.lags_delta", "consumer_lag_stored_d")
          ].freeze

          configure

          # @param block [Proc] optional configuration block
          def initialize(&block)
            configure
            setup(&block) if block
          end

          # @param block [Proc] configuration block
          # @note We define this alias to be consistent with `Karafka#setup`
          def setup(&)
            configure(&)
          end

          # Publishes rdkafka statistics: client-level, broker-level, and per-topic/partition lag.
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_statistics_emitted(event)
            statistics = event[:statistics]
            group_id = event[:group_id]

            rd_kafka_metrics.each do |metric|
              report_metric(metric, statistics, group_id)
            end
          end

          # Records error count. Error type and consumer context are embedded in the metric name.
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_error_occurred(event)
            type = event[:type].tr(".", "_")
            record("error_occurred.#{type}", 1)
          end

          # Records polling time and message count per consumer group fetch loop.
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_connection_listener_fetch_loop_received(event)
            group_id = event[:subscription_group].group.id

            record("listener.polling.time_taken.#{group_id}", event[:time])
            record("listener.polling.messages.#{group_id}", event[:messages_buffer].size)
          end

          # Records per-batch consumption metrics: message count, offset, timing, and lag.
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_consumed(event)
            consumer = event.payload[:caller]
            messages = consumer.messages
            metadata = messages.metadata
            suffix = consumer_suffix(consumer)

            record("consumer.messages.#{suffix}", messages.size)
            record("consumer.batches.#{suffix}", 1)
            record("consumer.offset.#{suffix}", metadata.last_offset)
            record("consumer.consumed.time_taken.#{suffix}", event[:time])
            record("consumer.batch_size.#{suffix}", messages.size)
            record("consumer.processing_lag.#{suffix}", metadata.processing_lag)
            record("consumer.consumption_lag.#{suffix}", metadata.consumption_lag)
          end

          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_revoked(event)
            record("consumer.revoked.#{consumer_suffix(event.payload[:caller])}", 1)
          end

          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_shutdown(event)
            record("consumer.shutdown.#{consumer_suffix(event.payload[:caller])}", 1)
          end

          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_ticked(event)
            record("consumer.tick.#{consumer_suffix(event.payload[:caller])}", 1)
          end

          # Records worker queue depth and thread utilization.
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_worker_process(event)
            jq_stats = event[:jobs_queue].statistics

            record("worker.total_threads", Karafka::Server.workers.size)
            record("worker.processing", jq_stats[:busy])
            record("worker.enqueued_jobs", jq_stats[:enqueued])
          end

          # Re-records worker processing count after a job completes for higher accuracy.
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_worker_processed(event)
            record("worker.processing", event[:jobs_queue].statistics[:busy])
          end

          private

          # Publishes a single rdkafka metric, encoding scope context into the metric name.
          #
          # @param metric [RdKafkaMetric]
          # @param statistics [Hash]
          # @param group_id [String]
          def report_metric(metric, statistics, group_id)
            case metric.scope
            when :root
              record("#{metric.name}.#{group_id}", statistics.dig(*Array(metric.key_location)))
            when :brokers
              statistics.fetch("brokers").each_value do |broker_stats|
                # Skip bootstrap nodes (nodeid == -1)
                next if broker_stats["nodeid"] == -1

                broker = broker_stats["nodename"].tr(":", "_")
                record("#{metric.name}.#{broker}", broker_stats.dig(*Array(metric.key_location)))
              end
            when :topics
              statistics.fetch("topics").each do |topic_name, topic_values|
                topic_values["partitions"].each do |partition_name, partition_stats|
                  next if partition_name == "-1"
                  # Skip until lag info is available from the broker
                  next if partition_stats["consumer_lag"] == -1
                  next if partition_stats["consumer_lag_stored"] == -1
                  # Skip partitions not owned by this consumer instance
                  next if partition_stats["fetch_state"] == "stopped"
                  next if partition_stats["fetch_state"] == "none"

                  record(
                    "#{metric.name}.#{topic_name}.#{partition_name}",
                    partition_stats.dig(*Array(metric.key_location))
                  )
                end
              end
            else
              raise ArgumentError, "Unknown metric scope: #{metric.scope}"
            end
          end

          # Builds a namespaced metric name and delegates to the client.
          #
          # @param key [String] metric key (without namespace prefix)
          # @param value [Numeric] metric value
          def record(key, value)
            client.record_metric("Custom/#{namespace}/#{key}", value)
          end

          # Returns a dot-joined suffix encoding consumer group, topic, and partition.
          #
          # @param consumer [Karafka::BaseConsumer]
          # @return [String]
          def consumer_suffix(consumer)
            metadata = consumer.messages.metadata
            group_id = consumer.topic.group.id

            "#{group_id}.#{metadata.topic}.#{metadata.partition}"
          end
        end
      end
    end
  end
end
