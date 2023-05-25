# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Vendors
      module PrometheusExporter
        class MetricsListener
          # Interfaces with a Karafka::Core::Monitoring::Event#on_statistics_emitted to extract librdkafka metrics
          # This listener needs additional setup to be fired.
          # #on_statistics_emitted is called by both consumers and producers
          # Karafka on its own only reports librdkafka metrics if the appropriate config (statistics emitted interval) is set in karafka.rb
          # A Full list of librdkafka metrics can be found at: https://github.com/edenhill/librdkafka/blob/master/STATISTICS.md
          class OnStatisticsEmitted
            attr_reader :statistics, :labels, :event

            def self.call(**args)
              new(**args).call
            end

            # @param listener [Karafka::Instrumentation::Vendors::PrometheusExporter::MetricsListener]
            # @param event [Karafka::Core::Monitoring::Event]
            def initialize(listener:, event:)
              @event = event
              @statistics = event[:statistics]
              @labels = listener.default_labels.merge(source_labels)
            end

            # Extract & observe metric from Karafka::Core::Monitoring::Event
            # @return [self]
            def call
              extract_metrics!
              self
            end

            def metrics
              @metrics ||= Hash.new { |hash, key| hash[key] = [] }
            end

            private

            def extract_metrics!
              metric_config.each do |name, metric|
                scope, source = metric.values_at("scope", "source")
                next unless source == "rd_kafka"
                extract_metric(name, scope)
              end
            end

            # Producer and consumer_group ids are not in every event
            # If present this extracts them from the event payload
            # we can then add them to the labels
            # @return [Hash]
            def source_labels
              event.payload.slice(:producer_id, :consumer_group_id)
            end

            # Reports a given metric statistics to Prometheus
            # @param [String] metric_name
            # @param [String] scope
            def extract_metric(name, scope)
              case scope
              when "root" then extract_root(name)
              when "brokers" then extract_brokers(name)
              when "topics" then extract_topics(name)
              else raise ArgumentError, metric_scope
              end
            end

            def extract_root(metric_name)
              metric = metric_config[metric_name]
              value = parse_value(statistics, metric)
              metrics[metric_name] << [value, labels]
            end

            def extract_brokers(metric_name)
              statistics.fetch("brokers").each_value do |broker_statistics|
                # Skip bootstrap nodes
                # Bootstrap nodes have nodeid -1,
                # other nodes have positive node ids
                next if broker_statistics["nodeid"] == -1

                metric = metric_config[metric_name]
                value = parse_value(broker_statistics, metric)
                broker, name = broker_statistics.values_at("nodename", "name")
                broker_labels = labels.merge(broker: broker, name: name)
                metrics[metric_name] << [value, broker_labels]
              end
            end

            def extract_topics(metric_name)
              statistics.fetch("topics").each do |topic_name, topic_values|
                topic_values["partitions"].each do |partition_name, partition_statistics|
                  # Skip until lag info is available
                  next if partition_name == "-1" || partition_statistics["consumer_lag"] == -1

                  metric = metric_config[metric_name]
                  value = parse_value(partition_statistics, metric)
                  topic_labels = labels.merge(topic: topic_name, partition: partition_name)
                  metrics[metric_name] << [value, topic_labels]
                end
              end
            end

            def metric_config
              MetricsCollector::CONFIG
            end

            def parse_value(statistics, metric)
              value = statistics.dig(*metric["key_location"])
              return value unless metric["conversion"]
              converter.fetch(metric["conversion"]).call(value)
            end

            def converter
              {
               "microseconds_to_seconds" => ->(value) { value / 1_000_000.0 },
               "milliseconds_to_seconds" => ->(value) { value / 1_000.0 },
              }
            end
          end
        end
      end
    end
  end
end
