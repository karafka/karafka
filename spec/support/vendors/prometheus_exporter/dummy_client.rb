# frozen_string_literal: true

require 'karafka/instrumentation/vendors/prometheus_exporter/metrics_collector'

# Vendors specific support components
module Vendors
  # Namespace for Prometheus Exporter specific support classes
  module PrometheusExporter
    # Dummy prometheus client that accumulates metrics that are added instead of sending them
    # This allows us not to be dependent on the prometheus exporter gem but also be able to test out the
    # integration
    class DummyClient
      attr_reader :collector

      def initialize(prom_collector = nil)
        @collector = prom_collector || ::Karafka::Instrumentation::Vendors::PrometheusExporter::MetricsCollector.new
      end

      def send_json(obj)
        @collector.collect(JSON.parse(obj.to_json)) # Fake the JSON serialization
        @collector.metrics # Fake a hit to the metrics endpoint
      end
    end
  end
end
