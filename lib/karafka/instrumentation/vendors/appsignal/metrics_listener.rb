# frozen_string_literal: true

require_relative 'base'

module Karafka
  module Instrumentation
    module Vendors
      # Namespace for Appsignal instrumentation
      module Appsignal
        # Listener that ships metrics to Appsignal
        class MetricsListener < Base
          def_delegators :config, :client, :rd_kafka_metrics, :namespace

          # Value object for storing a single rdkafka metric publishing details
          RdKafkaMetric = Struct.new(:type, :scope, :name, :key_location)

          setting :namespace, default: 'karafka'

          setting :client, default: Client.new

          setting :rd_kafka_metrics, default: [
            # Broker metrics
            RdKafkaMetric.new(:count, :brokers, 'requests_retries', 'txretries_d'),
            RdKafkaMetric.new(:count, :brokers, 'transmission_errors', 'txerrs_d'),
            RdKafkaMetric.new(:count, :brokers, 'receive_errors', 'rxerrs_d'),
            RdKafkaMetric.new(:count, :brokers, 'connection_connects', 'connects_d'),
            RdKafkaMetric.new(:count, :brokers, 'connection_disconnects', 'disconnects_d'),
            RdKafkaMetric.new(:gauge, :brokers, 'network_latency_avg', %w[rtt avg]),
            RdKafkaMetric.new(:gauge, :brokers, 'network_latency_p95', %w[rtt p95]),
            RdKafkaMetric.new(:gauge, :brokers, 'network_latency_p99', %w[rtt p99]),

            # Topics partitions metrics
            RdKafkaMetric.new(:gauge, :topics, 'consumer_lag', 'consumer_lag_stored'),
            RdKafkaMetric.new(:gauge, :topics, 'consumer_lag_delta', 'consumer_lag_stored_d')
          ].freeze

          # Metrics that sum values on topics levels and not on partition levels
          setting :aggregated_rd_kafka_metrics, default: [
            # Topic aggregated metrics
            RdKafkaMetric.new(:gauge, :topics, 'consumer_aggregated_lag', 'consumer_lag_stored')
          ].freeze

          configure

          # Types of errors originating from user code in the consumer flow
          USER_CONSUMER_ERROR_TYPES = %w[
            consumer.consume.error
            consumer.revoked.error
            consumer.shutdown.error
            consumer.tick.error
            consumer.eofed.error
          ].freeze

          private_constant :USER_CONSUMER_ERROR_TYPES

          # Before each consumption process, lets start a transaction associated with it
          # We also set some basic metadata about the given consumption that can be useful for
          # debugging
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_consume(event)
            consumer = event.payload[:caller]

            start_transaction(consumer, 'consume')

            client.metadata = {
              batch_size: consumer.messages.size,
              first_offset: consumer.messages.metadata.first_offset,
              last_offset: consumer.messages.metadata.last_offset,
              consumer_group: consumer.topic.consumer_group.id,
              topic: consumer.topic.name,
              partition: consumer.partition,
              attempt: consumer.coordinator.pause_tracker.attempt
            }
          end

          # Once we're done with consumption, we bump counters about that
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_consumed(event)
            consumer = event.payload[:caller]
            messages = consumer.messages
            metadata = messages.metadata

            with_multiple_resolutions(consumer) do |tags|
              count('consumer_messages', messages.size, tags)
              count('consumer_batches', 1, tags)
              gauge('consumer_offsets', metadata.last_offset, tags)
            end

            stop_transaction
          end

          # Register minute based probe only on app running. Otherwise if we would always register
          # minute probe, it would report on processes using Karafka but not running the
          # consumption process
          #
          # @param _event [Karafka::Core::Monitoring::Event]
          def on_app_running(_event)
            return if @probe_registered

            @probe_registered = true

            # Registers the minutely probe for one-every-minute metrics
            client.register_probe(:karafka, -> { minute_probe })
          end

          [
            %i[revoke revoked revoked],
            %i[shutting_down shutdown shutdown],
            %i[tick ticked tick],
            %i[eof eofed eofed]
          ].each do |before, after, name|
            class_eval <<~RUBY, __FILE__, __LINE__ + 1
              # Keeps track of user code execution
              #
              # @param event [Karafka::Core::Monitoring::Event]
              def on_consumer_#{before}(event)
                consumer = event.payload[:caller]
                start_transaction(consumer, '#{name}')
              end

              # Finishes the transaction
              #
              # @param _event [Karafka::Core::Monitoring::Event]
              def on_consumer_#{after}(_event)
                stop_transaction
              end
            RUBY
          end

          # Counts DLQ dispatches
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_dead_letter_queue_dispatched(event)
            consumer = event.payload[:caller]

            with_multiple_resolutions(consumer) do |tags|
              count('consumer_dead', 1, tags)
            end
          end

          # Reports on **any** error that occurs. This also includes non-user related errors
          # originating from the framework.
          #
          # @param event [Karafka::Core::Monitoring::Event] error event details
          def on_error_occurred(event)
            # If this is a user consumption related error, we bump the counters for metrics
            if USER_CONSUMER_ERROR_TYPES.include?(event[:type])
              consumer = event.payload[:caller]

              with_multiple_resolutions(consumer) do |tags|
                count('consumer_errors', 1, tags)
              end
            end

            stop_transaction
          end

          # Hooks up to Karafka instrumentation for emitted statistics
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_statistics_emitted(event)
            statistics = event[:statistics]
            consumer_group_id = event[:consumer_group_id]

            rd_kafka_metrics.each do |metric|
              report_metric(metric, statistics, consumer_group_id)
            end

            report_aggregated_topics_metrics(statistics, consumer_group_id)
          end

          # Reports a given metric statistics to Appsignal
          # @param metric [RdKafkaMetric] metric value object
          # @param statistics [Hash] hash with all the statistics emitted
          # @param consumer_group_id [String] cg in context which we operate
          def report_metric(metric, statistics, consumer_group_id)
            case metric.scope
            when :root
              # Do nothing on the root metrics as the same metrics are reported in a granular
              # way from other places
              nil
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
                  {
                    broker: broker_statistics['nodename']
                  }
                )
              end
            when :topics
              statistics.fetch('topics').each do |topic_name, topic_values|
                topic_values['partitions'].each do |partition_name, partition_statistics|
                  next if partition_name == '-1'
                  # Skip until lag info is available
                  next if partition_statistics['consumer_lag'] == -1
                  next if partition_statistics['consumer_lag_stored'] == -1

                  # Skip if we do not own the fetch assignment
                  next if partition_statistics['fetch_state'] == 'stopped'
                  next if partition_statistics['fetch_state'] == 'none'

                  public_send(
                    metric.type,
                    metric.name,
                    partition_statistics.dig(*metric.key_location),
                    {
                      consumer_group: consumer_group_id,
                      topic: topic_name,
                      partition: partition_name
                    }
                  )
                end
              end
            else
              raise ArgumentError, metric.scope
            end
          end

          # Publishes aggregated topic-level metrics that are sum of per partition metrics
          #
          # @param statistics [Hash] hash with all the statistics emitted
          # @param consumer_group_id [String] cg in context which we operate
          def report_aggregated_topics_metrics(statistics, consumer_group_id)
            config.aggregated_rd_kafka_metrics.each do |metric|
              statistics.fetch('topics').each do |topic_name, topic_values|
                sum = 0

                topic_values['partitions'].each do |partition_name, partition_statistics|
                  next if partition_name == '-1'
                  # Skip until lag info is available
                  next if partition_statistics['consumer_lag'] == -1
                  next if partition_statistics['consumer_lag_stored'] == -1

                  sum += partition_statistics.dig(*metric.key_location)
                end

                public_send(
                  metric.type,
                  metric.name,
                  sum,
                  {
                    consumer_group: consumer_group_id,
                    topic: topic_name
                  }
                )
              end
            end
          end

          # Increments a counter with a namespace key, value and tags
          #
          # @param key [String] key we want to use (without the namespace)
          # @param value [Integer] count value
          # @param tags [Hash] additional extra tags
          def count(key, value, tags)
            client.count(
              namespaced_metric(key),
              value,
              tags
            )
          end

          # Sets the gauge value
          #
          # @param key [String] key we want to use (without the namespace)
          # @param value [Integer] gauge value
          # @param tags [Hash] additional extra tags
          def gauge(key, value, tags)
            client.gauge(
              namespaced_metric(key),
              value,
              tags
            )
          end

          private

          # Wraps metric name in listener's namespace
          # @param metric_name [String] RdKafkaMetric name
          # @return [String]
          def namespaced_metric(metric_name)
            "#{namespace}_#{metric_name}"
          end

          # Starts the transaction for monitoring user code
          #
          # @param consumer [Karafka::BaseConsumer] karafka consumer instance
          # @param action_name [String] lifecycle user method name
          def start_transaction(consumer, action_name)
            client.start_transaction(
              "#{consumer.class}##{action_name}"
            )
          end

          # Stops the transaction wrapping user code
          def stop_transaction
            client.stop_transaction
          end

          # @param consumer [Karafka::BaseConsumer] Karafka consumer instance
          def with_multiple_resolutions(consumer)
            topic_name = consumer.topic.name
            consumer_group_id = consumer.topic.consumer_group.id
            partition = consumer.partition

            tags = {
              consumer_group: consumer_group_id,
              topic: topic_name
            }

            yield(tags)
            yield(tags.merge(partition: partition))
          end

          # Sends minute based probing metrics
          def minute_probe
            concurrency = Karafka::App.config.concurrency

            count('processes_count', 1, {})
            count('threads_count', concurrency, {})
          end
        end
      end
    end
  end
end
