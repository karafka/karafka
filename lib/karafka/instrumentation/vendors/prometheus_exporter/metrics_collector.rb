# frozen_string_literal: true

require "yaml"
# Note prometheus exporter does not load rails and dependencies
# You must manually require anything you need outside of prometheus_exporter
# This includes Rails helpers like deep_symbolize_keys, present? for a hash, etc
module Karafka
  module Instrumentation
    module Vendors
      module PrometheusExporter
        # The metrics collector is responsible for collecting metrics from the event payload
        # The collector is only run on the prometheus_exporter server and not in the karafka app
        # Once tested ideally it is added directly to the prometheus_exporter repository as a standard collector
        # Once added to prometheus_exporter, Karafka no longer needs to maintain this file
        class MetricsCollector < ::PrometheusExporter::Server::TypeCollector
          # @return [Hash] registry, hash of metric names to their config
          attr_reader :registry

          CONFIG = YAML.load_file(
            File.join(__dir__, "metrics_collector", "config.yaml")
          ).freeze

          def initialize
            @registry = {}
          end

          # @param [Hash] hash of metric names to values: {'consumer_lags_delta=' => [2, {label: 1 }] }
          # @return [Hash] the same hash passed in
          def collect(obj)
            ensure_metrics!
            observe_metrics!(obj)
          end

          # @return [Array<PrometheusExporter::Metric::Base>] Instantiated Prometheus metrics (gauges, counters, etc)
          def metrics
            @registry.values
          end

          def type
            "kafka"
          end

          protected

          # @param [Hash] hash of metric names to values: {'consumer_lags_delta' => [2, {label: 1 }] }
          def observe_metrics!(obj)
            if obj.nil? || obj.empty? || obj["payload"].nil? || obj["payload"].empty?
              return warn("No kafka metrics to observe")
            end

            obj["payload"].each do |metric_name, payload|
              metric = registry[metric_name]
              next observe_metric(metric, payload) if metric && !payload.empty?
              warn "Undefined metric: '#{metric_name}', for metrics: #{registry.keys}"
            rescue StandardError => e
              warn "Uncaught exception: #{e.message}, processing metric: '#{metric_name}' with payload: #{payload}"
            end
          end

          # @param [::PrometheusExporter::Metric::Base] metric
          # @param [Array] payload, array of tuples: [value, {label: 1}] or [[value, {label: 1}], [value, {label: 2}]]
          def observe_metric(metric, payload)
            if !payload[0].is_a? Array
              metric.observe(*payload)
            else
              payload.each do |tuple|
                metric.observe(*tuple)
              end
            end
          end

          # @return [Hash] config, hash of metric names to their config
          def ensure_metrics!
            return CONFIG unless registry.empty?

            CONFIG.each do |metric_name, config|
              type, description, buckets, quantiles = config.values_at("type", "description", "buckets", "quantiles")
              metric_klass = ::PrometheusExporter::Metric.const_get(type)
              args = [metric_name, description, buckets || quantiles].compact

              registry[metric_name] = metric_klass.new(*args)
            end
          end
        end
      end
    end
  end
end
