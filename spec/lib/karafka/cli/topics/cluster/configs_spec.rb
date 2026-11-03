# frozen_string_literal: true

RSpec.describe_current do
  subject(:cluster_configs) { described_class.new(topic_name) }

  let(:topic_name) { generate_topic_name }

  before { Karafka::Admin.create_topic(topic_name, 1, 1) }

  describe "#names" do
    it { expect(cluster_configs.names).to include("retention.ms", "cleanup.policy") }
    it { expect(cluster_configs.names).to include("log.retention.bytes") }
  end

  describe "#unknown" do
    let(:configs) do
      {
        "retention.ms": 86_400_000,
        "log.retention.bytes": 1_000,
        "retention.msx": 86_400_000
      }
    end

    it "expect to return only configs the cluster does not know, as strings" do
      expect(cluster_configs.unknown(configs)).to eq("retention.msx" => "86400000")
    end

    it { expect(cluster_configs.unknown("retention.ms": 1)).to eq({}) }
  end
end
