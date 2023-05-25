# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Namespace for vendor specific instrumentation
    module Vendors
      # Prometheus Exporter specific instrumentation
      module PrometheusExporter
        # Listener that can be used to subscribe to Karafka to send stats
        # to a Prometheus Exporter server
        #
        # @note You need to run the `prometheus_exporter` server and pass the karafka collector
        # `prometheus_exporter -a path/to/prometheus_exporter/metrics_collector.rb`
        class MetricsListener
          include ::Karafka::Core::Configurable
          extend Forwardable

          def_delegators :config, :client, :metric_config, :namespace, :default_labels

          # Value object for storing a single rdkafka metric publishing details
          RdKafkaMetric = Struct.new(:type, :scope, :name, :key_location)

          # Namespace under which the DD metrics should be published
          setting :namespace, default: 'karafka'

          # Prometheus Exporter client that we should use to publish the metrics
          # Usually you'll want ::PrometheusExporter::Client.default
          setting :client

          # Default labels we want to publish (for example hostname)
          # Format as followed (example for hostname): `{ host: Socket.gethostname }`
          setting :default_labels, default: {}

          # All the rdkafka metrics we want to publish
          #
          # By default we publish quite a lot so this can be tuned
          setting :metric_config, default: ::Karafka::Instrumentation::Vendors::PrometheusExporter::MetricsCollector::CONFIG

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
            metrics = OnStatisticsEmitted.call(listener: self, event: event).metrics
            observe(metrics)
          end

          # Increases the errors count by 1
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_error_occurred(event)
            labels = default_labels.merge(type: event[:type])

            if event.payload[:caller].respond_to?(:messages)
              labels = labels.merge(consumer_labels(event.payload[:caller]))
            end

            observe(karafka_error_total: [1, labels])
          end

          # Reports how many messages we've polled and how much time did we spend on it
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_connection_listener_fetch_loop_received(event)
            time_taken = event[:time] / 1000 # convert to seconds to adhere to prometheus standards
            message_count = event[:messages_buffer].size

            consumer_group_id = event[:subscription_group].consumer_group_id

            labels = default_labels.merge(consumer_group: consumer_group_id)

            observe(
              karafka_listener_polling_time_seconds: [time_taken, labels],
              karafka_listener_polling_messages: [message_count, labels]
            )
          end

          # Here we report majority of things related to processing as we have access to the
          # consumer
          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_consumed(event)
            consumer = event.payload[:caller]
            messages = consumer.messages
            metadata = messages.metadata
            time_taken = event[:time] / 1000 # convert to seconds to adhere to prometheus standards
            proccess_lag = metadata.processing_lag / 1000
            consumption_lag = metadata.consumption_lag / 1000

            labels = default_labels.merge(consumer_labels(consumer))

            observe(
              karafka_consumer_messages_total: [messages.count, labels],
              karafka_consumer_batches_total: [1, labels],
              karafka_consumer_offset: [metadata.last_offset, labels],
              karafka_consumer_consumed_time_taken_seconds: [time_taken, labels],
              karafka_consumer_batch_size: [messages.count, labels],
              karafka_consumer_processing_lag_seconds: [processing_lag, labels],
              karafka_consumer_consumption_lag_seconds: [consumption_lag, labels]
            )
          end

          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_revoked(event)
            labels = default_labels.merge(consumer_labels(event.payload[:caller]))

            observe(karafka_consumer_revoked_total: [1, labels])
          end

          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_shutdown(event)
            labels = default_labels.merge(consumer_labels(event.payload[:caller]))

            observe(karafka_consumer_shutdown_total: [1, labels])
          end

          # Worker related metrics
          # @param event [Karafka::Core::Monitoring::Event]
          def on_worker_process(event)
            jobs_queue_stats = event[:jobs_queue].statistics

            observe(
              karafka_worker_threads: [Karafka::App.config.concurrency, default_labels],
              karafka_worker_threads_busy: [jobs_queue_stats[:busy], default_labels],
              karafka_worker_enqueued_jobs: [jobs_queue_stats[:enqueued], default_labels]
            )
          end

          # We report this metric before and after processing for higher accuracy
          # Without this, the utilization would not be fully reflected
          # @param event [Karafka::Core::Monitoring::Event]
          def on_worker_processed(event)
            jobs_queue_stats = event[:jobs_queue].statistics
            count = jobs_queue_stats[:busy] || 0
            observe(karafka_worker_threads_busy: [count, default_labels])
          end

          private

          # @param [Hash] metrics to send to the prometheus exporter server
          def observe(metrics)
            client.send_json({
              type: "kafka",
              payload: metrics
            })
          end

          # Builds basic per consumer labels for publication
          #
          # @param consumer [Karafka::BaseConsumer]
          # @return [Hash]
          def consumer_labels(consumer)
            messages = consumer.messages
            metadata = messages.metadata
            consumer_group_id = consumer.topic.consumer_group.id

            {
              topic: metadata.topic,
              partition: metadata.partition,
              consumer_group: consumer_group_id
            }
          end
        end
      end
    end
  end
end
