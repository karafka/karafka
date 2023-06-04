
require "karafka/instrumentation/vendors/prometheus_exporter/metrics_listener"
require 'prometheus_exporter'
require 'prometheus_exporter/server'
# These are integration tests, not unit tests.
# Collectors live on the prometheus server, not the karafka server.
RSpec.describe_current do
  subject(:collector) { described_class.new }

  let(:payload) { {"payload" => {"app_stopped_total" => [1, {}]}} }

  it "initiliazes with an empty registry" do
    expect(collector.registry).to eql({})
  end

  it "ensures metrics are registered when collected" do
    collector.collect(payload)
    described_class::CONFIG.each do |metric_name, config|
      metric_klass = PrometheusExporter::Metric.const_get(config["type"])
      name = collector.send(:namespace, metric_name)
      expect(collector.registry[name]).to be_an_instance_of(metric_klass)
    end
  end

  it "expects a type of karafka" do
    expect(collector.type).to eql("karafka")
  end

end
