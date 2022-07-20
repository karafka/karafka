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
          include WaterDrop::Configurable
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
            RdKafkaMetric.new(:gauge, :brokers, 'network.latency.p99', %w[rtt p99])
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
          # @param event [Dry::Events::Event]
          def on_statistics_emitted(event)
            statistics = event[:statistics]

            rd_kafka_metrics.each do |metric|
              report_metric(metric, statistics)
            end
          end

          # Increases the errors count by 1
          #
          # @param event [Dry::Events::Event]
          def on_error_occurred(event)
            extra_tags = ["type:#{event[:type]}"]

            if event.payload[:caller].respond_to?(:messages)
              metadata = event.payload[:caller].messages.metadata

              extra_tags += [
                "topic:#{metadata.topic}",
                "partition:#{metadata.partition}"
              ]
            end

            client.count(
              namespaced_metric('error_occurred'),
              1,
              tags: default_tags + extra_tags
            )
          end

          # Reports how many message we have consumed and how many batches
          def on_consumer_consumed(event)
            messages = event.payload[:caller].messages
            metadata = messages.metadata

            extra_tags = [
              "topic:#{metadata.topic}",
              "partition:#{metadata.partition}"
            ]

            client.histogram(
              namespaced_metric('consumer.time_taken'),
              event[:time],
              tags: default_tags + extra_tags
            )

            client.count(
              namespaced_metric('consumer.messages'),
              messages.count,
              tags: default_tags + extra_tags
            )

            client.count(
              namespaced_metric('consumer.batches'),
              1,
              tags: default_tags + extra_tags
            )

            client.histogram(
              namespaced_metric('consumer.processing_lag'),
              metadata.processing_lag,
              tags: default_tags + extra_tags
            )

            client.histogram(
              namespaced_metric('consumer.consumption_lag'),
              metadata.consumption_lag,
              tags: default_tags + extra_tags
            )

            client.gauge(
              namespaced_metric('consumer.offset'),
              metadata.last_offset,
              tags: default_tags + extra_tags
            )
          end

          def on_worker_process(event)
            client.histogram(
              namespaced_metric('worker.processing'),
              event[:jobs_queue].statistics[:processing],
              tags: default_tags
            )

            client.gauge(
              namespaced_metric('worker.total_threads'),
              Karafka::App.config.concurrency,
              tags: default_tags
            )

            client.histogram(
              namespaced_metric('worker.enqueued_jobs'),
              event[:jobs_queue].statistics[:enqueued],
              tags: default_tags
            )
          end

          def on_worker_processed(event)
            client.histogram(
              namespaced_metric('worker.processing'),
              event[:jobs_queue].statistics[:processing],
              tags: default_tags
            )
          end

          # delay miedzy przyjsciem wiadomosci a zaczeciem procesowania (lag)
          # max message batch size
          # p95 batch size
          # Message lag changes
          # Messages consumed in timeframe

          private

          # Wraps metric name in listener's namespace
          # @param metric_name [String] RdKafkaMetric name
          # @return [String]
          def namespaced_metric(metric_name)
            "#{namespace}.#{metric_name}"
          end

          # Reports a given metric statistics to Datadog
          # @param metric [RdKafkaMetric] metric value object
          # @param statistics [Hash] hash with all the statistics emitted
          def report_metric(metric, statistics)
            case metric.scope
            when :root
              client.public_send(
                metric.type,
                namespaced_metric(metric.name),
                statistics.fetch(*metric.key_location),
                tags: default_tags
              )
            when :brokers
              statistics.fetch('brokers').each_value do |broker_statistics|
                # Skip bootstrap nodes
                # Bootstrap nodes have nodeid -1, other nodes have positive
                # node ids
                next if broker_statistics['nodeid'] == -1

                client.public_send(
                  metric.type,
                  namespaced_metric(metric.name),
                  broker_statistics.dig(*metric.key_location),
                  tags: default_tags + ["broker:#{broker_statistics['nodename']}"]
                )
              end
            else
              raise ArgumentError, metric.scope
            end
          end
        end
      end
    end
  end
end
