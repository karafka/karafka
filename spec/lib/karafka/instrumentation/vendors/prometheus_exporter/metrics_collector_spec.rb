
require "karafka/instrumentation/vendors/prometheus_exporter/metrics_listener"
require 'prometheus_exporter'
require 'prometheus_exporter/server'
# These are integration tests, not unit tests.
# Collectors live on the prometheus server, not the karafka server.
RSpec.describe_current do
  subject(:collector) { described_class.new }

  let(:payload) { {"payload" => {"app_stopped_total" => [1, {}]}} }

  before do
    # Stub out the clock to allow time travel and test metric expiration
    allow(Process).to receive(:clock_gettime).and_return(0)
  end

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

  context "when collecting persistent metrics" do
    let(:labels) do
      {
        "host"=>"88a375b114dd",
        "app"=>"karafka",
        "consumer_group"=>"dummy_app"
      }
    end
    let(:payload) do
      {
        "type"=>"karafka",
        "payload"=> {
          "listener_polling_time_seconds"=> [1.01, labels],
          "listener_polling_messages"=> [0, labels]
        }
      }
    end

    before do
      collector.collect(payload)
      polling_time_metric = collector.registry["karafka_listener_polling_time_seconds"]
      polling_msg_metric = collector.registry["karafka_listener_polling_messages"]
      allow(polling_time_metric).to receive(:observe).and_call_original
      allow(polling_msg_metric).to receive(:observe).and_call_original
    end

    it "resets persistent_metrics after observation" do
      expect(collector.persistent_metrics).to be_present
      collector.metrics
      expect(collector.persistent_metrics).to be_empty
    end

    it "observes persistent metrics" do
      polling_metric = collector.registry["karafka_listener_polling_time_seconds"]
      polling_msg_metric = collector.registry["karafka_listener_polling_messages"]
      expect(polling_metric).to receive(:observe).with(1.01, hash_including(labels))
      expect(polling_msg_metric).to receive(:observe).with(0, hash_including(labels))
      collector.metrics
    end
  end

  context "when collecting expiring metrics" do
    let(:labels) do
      {
        "host"=>"88a375b114dd",
        "app"=>"karafka",
        "producer_id"=>"0f10416fee3e",
        "broker"=>"karafka:9092",
        "name"=>"karafka:9092/1002"
      }
    end
    let(:payload) do
      {
        "type"=>"karafka",
        "payload"=> {
          "queue_latency_avg_seconds"=> [[0.0, labels]],
          "queue_latency_p95_seconds"=> [[0.0, labels]]
        }
      }
    end

    before do
      collector.collect(payload)
      latency_avg_metric = collector.registry["karafka_queue_latency_avg_seconds"]
      latency_p95_metric = collector.registry["karafka_queue_latency_p95_seconds"]
      allow(latency_avg_metric).to receive(:observe).and_call_original
      allow(latency_p95_metric).to receive(:observe).and_call_original
    end

    it "does not reset expireable_metrics after observation" do
      expect(collector.expireable_metrics.data).to be_present
      collector.metrics
      expect(collector.expireable_metrics.data).to be_present
    end

    it "observes expireable metrics" do
      latency_avg_metric = collector.registry["karafka_queue_latency_avg_seconds"]
      latency_p95_metric = collector.registry["karafka_queue_latency_p95_seconds"]
      expect(latency_avg_metric).to receive(:observe).with(0.0, hash_including(labels))
      expect(latency_p95_metric).to receive(:observe).with(0.0, hash_including(labels))
      collector.metrics
    end

    context "when a metric expires" do
      before do
        allow(Process).to receive(:clock_gettime).and_return(described_class::MAX_METRIC_AGE + 1)
      end
      it "is no longer observed" do
        latency_avg_metric = collector.registry["karafka_queue_latency_avg_seconds"]
        latency_p95_metric = collector.registry["karafka_queue_latency_p95_seconds"]
        collector.metrics
        expect(collector.expireable_metrics.data).to be_empty
        expect(collector.registry["karafka_queue_latency_p95_seconds"].data).to be_empty
      end
    end
  end
end
