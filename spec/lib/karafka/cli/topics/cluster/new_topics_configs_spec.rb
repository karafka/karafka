# frozen_string_literal: true

RSpec.describe_current do
  subject(:unknown) do
    Karafka::Admin.with_admin do |admin|
      described_class.new(admin).unknown(topic, configs)
    end
  end

  let(:topic) { Karafka::Declaratives::Topic.new(topic_name) }
  let(:topic_name) { generate_topic_name }
  let(:topics_names) { Karafka::Admin.cluster_info.topics.map { |topic| topic[:topic_name] } }

  context "when the cluster knows all the configs names" do
    let(:configs) { { "retention.ms" => "1", "cleanup.policy" => "compact" } }

    it { expect(unknown).to eq([]) }

    it "expect not to create the topic" do
      unknown
      expect(topics_names).not_to include(topic_name)
    end
  end

  context "when the cluster does not know some configs names" do
    let(:configs) { { "retention.msx" => "1", "retention.ms" => "1", "cleanup.policyx" => "x" } }

    it { expect(unknown).to eq(%w[retention.msx cleanup.policyx]) }

    it "expect not to create the topic" do
      unknown
      expect(topics_names).not_to include(topic_name)
    end
  end

  context "when a config name is a synonym" do
    let(:configs) { { "log.retention.bytes" => "1" } }

    it { expect(unknown).to eq(%w[log.retention.bytes]) }
  end

  context "when a known config has an invalid value" do
    let(:configs) { { "retention.ms" => "invalid", "retention.msx" => "1" } }

    it { expect(unknown).to eq(%w[retention.msx]) }
  end

  context "when the replication factor is higher than the number of brokers" do
    before { topic.replication_factor = 100 }

    context "when the cluster does not know a config name" do
      let(:configs) { { "retention.msx" => "1" } }

      it { expect(unknown).to eq(%w[retention.msx]) }
    end

    context "when the cluster knows all the configs names" do
      let(:configs) { { "retention.ms" => "1" } }

      it { expect { unknown }.to raise_error(Rdkafka::RdkafkaError, /replication/) }
    end
  end

  context "when the validation fails for a different reason" do
    let(:configs) { { "retention.msx" => "1" } }

    before { Karafka::Admin.create_topic(topic_name, 1, 1) }

    it { expect { unknown }.to raise_error(Rdkafka::RdkafkaError, /topic_already_exists/) }
  end
end
