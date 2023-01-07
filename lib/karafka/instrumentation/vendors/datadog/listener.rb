# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Namespace for vendor specific instrumentation
    module Vendors
      # Datadog specific instrumentation
      module Datadog
        # Listener that can be used to subscribe to Karafka to receive stats via StatsD
        # and/or Datadog
        #
        # @note You need to setup the `dogstatsd-ruby` client and assign it
        class Listener
          include ::Karafka::Core::Configurable
          extend Forwardable

          def_delegators :config, :client, :rd_kafka_metrics, :namespace, :default_tags

          # Value object for storing a single rdkafka metric publishing details
          RdKafkaMetric = Struct.new(:type, :scope, :name, :key_location)

          # Namespace under which the DD metrics should be published
          setting :namespace, default: 'karafka'

          # Datadog client that we should use to publish the metrics
          setting :client

          # Default tags we want to publish (for example hostname)
          # Format as followed (example for hostname): `["host:#{Socket.gethostname}"]`
          setting :default_tags, default: []

          # All the rdkafka metrics we want to publish
          #
          # By default we publish quite a lot so this can be tuned
          # Note, that the once with `_d` come from Karafka, not rdkafka or Kafka
          setting :rd_kafka_metrics, default: [
            # Client metrics
            RdKafkaMetric.new(:count, :root, 'messages.consumed', 'rxmsgs_d'),
            RdKafkaMetric.new(:count, :root, 'messages.consumed.bytes', 'rxmsg_bytes'),

            # Broker metrics
            RdKafkaMetric.new(:count, :brokers, 'consume.attempts', 'txretries_d'),
            RdKafkaMetric.new(:count, :brokers, 'consume.errors', 'txerrs_d'),
            RdKafkaMetric.new(:count, :brokers, 'receive.errors', 'rxerrs_d'),
            RdKafkaMetric.new(:count, :brokers, 'connection.connects', 'connects_d'),
            RdKafkaMetric.new(:count, :brokers, 'connection.disconnects', 'disconnects_d'),
            RdKafkaMetric.new(:gauge, :brokers, 'network.latency.avg', %w[rtt avg]),
            RdKafkaMetric.new(:gauge, :brokers, 'network.latency.p95', %w[rtt p95]),
            RdKafkaMetric.new(:gauge, :brokers, 'network.latency.p99', %w[rtt p99]),

            # Topics metrics
            RdKafkaMetric.new(:gauge, :topics, 'consumer.lags', 'consumer_lag_stored'),
            RdKafkaMetric.new(:gauge, :topics, 'consumer.lags_delta', 'consumer_lag_stored_d')
          ].freeze

          configure

          # @param block [Proc] configuration block
          def initialize(&block)
            configure
            setup(&block) if block
          end

          # @param block [Proc] configuration block
          # @note We define this alias to be consistent with `WaterDrop#setup`
          def setup(&block)
            configure(&block)
          end

          # Hooks up to WaterDrop instrumentation for emitted statistics
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_statistics_emitted(event)
            statistics = event[:statistics]
            consumer_group_id = event[:consumer_group_id]

            base_tags = default_tags + ["consumer_group:#{consumer_group_id}"]

            rd_kafka_metrics.each do |metric|
              report_metric(metric, statistics, base_tags)
            end
          end

          # Increases the errors count by 1
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_error_occurred(event)
            extra_tags = ["type:#{event[:type]}"]

            if event.payload[:caller].respond_to?(:messages)
              extra_tags += consumer_tags(event.payload[:caller])
            end

            count('error_occurred', 1, tags: default_tags + extra_tags)
          end

          # Reports how many messages we've polled and how much time did we spend on it
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_connection_listener_fetch_loop_received(event)
            time_taken = event[:time]
            messages_count = event[:messages_buffer].size

            consumer_group_id = event[:subscription_group].consumer_group_id

            extra_tags = ["consumer_group:#{consumer_group_id}"]

            histogram('listener.polling.time_taken', time_taken, tags: default_tags + extra_tags)
            histogram('listener.polling.messages', messages_count, tags: default_tags + extra_tags)
          end

          # Here we report majority of things related to processing as we have access to the
          # consumer
          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_consumed(event)
            consumer = event.payload[:caller]
            messages = consumer.messages
            metadata = messages.metadata

            tags = default_tags + consumer_tags(consumer)

            count('consumer.messages', messages.count, tags: tags)
            count('consumer.batches', 1, tags: tags)
            gauge('consumer.offset', metadata.last_offset, tags: tags)
            histogram('consumer.consumed.time_taken', event[:time], tags: tags)
            histogram('consumer.batch_size', messages.count, tags: tags)
            histogram('consumer.processing_lag', metadata.processing_lag, tags: tags)
            histogram('consumer.consumption_lag', metadata.consumption_lag, tags: tags)
          end

          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_revoked(event)
            tags = default_tags + consumer_tags(event.payload[:caller])

            count('consumer.revoked', 1, tags: tags)
          end

          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_shutdown(event)
            tags = default_tags + consumer_tags(event.payload[:caller])

            count('consumer.shutdown', 1, tags: tags)
          end

          # Worker related metrics
          # @param event [Karafka::Core::Monitoring::Event]
          def on_worker_process(event)
            jq_stats = event[:jobs_queue].statistics

            gauge('worker.total_threads', Karafka::App.config.concurrency, tags: default_tags)
            histogram('worker.processing', jq_stats[:busy], tags: default_tags)
            histogram('worker.enqueued_jobs', jq_stats[:enqueued], tags: default_tags)
          end

          # We report this metric before and after processing for higher accuracy
          # Without this, the utilization would not be fully reflected
          # @param event [Karafka::Core::Monitoring::Event]
          def on_worker_processed(event)
            jq_stats = event[:jobs_queue].statistics

            histogram('worker.processing', jq_stats[:busy], tags: default_tags)
          end

          private

          %i[
            count
            gauge
            histogram
            increment
            decrement
          ].each do |metric_type|
            class_eval <<~METHODS, __FILE__, __LINE__ + 1
              def #{metric_type}(key, *args)
                client.#{metric_type}(
                  namespaced_metric(key),
                  *args
                )
              end
            METHODS
          end

          # Wraps metric name in listener's namespace
          # @param metric_name [String] RdKafkaMetric name
          # @return [String]
          def namespaced_metric(metric_name)
            "#{namespace}.#{metric_name}"
          end

          # Reports a given metric statistics to Datadog
          # @param metric [RdKafkaMetric] metric value object
          # @param statistics [Hash] hash with all the statistics emitted
          # @param base_tags [Array<String>] base tags we want to start with
          def report_metric(metric, statistics, base_tags)
            case metric.scope
            when :root
              public_send(
                metric.type,
                metric.name,
                statistics.fetch(*metric.key_location),
                tags: base_tags
              )
            when :brokers
              statistics.fetch('brokers').each_value do |broker_statistics|
                # Skip bootstrap nodes
                # Bootstrap nodes have nodeid -1, other nodes have positive
                # node ids
                next if broker_statistics['nodeid'] == -1

                public_send(
                  metric.type,
                  metric.name,
                  broker_statistics.dig(*metric.key_location),
                  tags: base_tags + ["broker:#{broker_statistics['nodename']}"]
                )
              end
            when :topics
              statistics.fetch('topics').each do |topic_name, topic_values|
                topic_values['partitions'].each do |partition_name, partition_statistics|
                  next if partition_name == '-1'
                  # Skip until lag info is available
                  next if partition_statistics['consumer_lag'] == -1

                  public_send(
                    metric.type,
                    metric.name,
                    partition_statistics.dig(*metric.key_location),
                    tags: base_tags + [
                      "topic:#{topic_name}",
                      "partition:#{partition_name}"
                    ]
                  )
                end
              end
            else
              raise ArgumentError, metric.scope
            end
          end

          # Builds basic per consumer tags for publication
          #
          # @param consumer [Karafka::BaseConsumer]
          # @return [Array<String>]
          def consumer_tags(consumer)
            messages = consumer.messages
            metadata = messages.metadata
            consumer_group_id = consumer.topic.consumer_group.id

            [
              "topic:#{metadata.topic}",
              "partition:#{metadata.partition}",
              "consumer_group:#{consumer_group_id}"
            ]
          end
        end
      end
    end
  end
end
