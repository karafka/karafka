# frozen_string_literal: true

RSpec.describe_current do
  subject(:unknown_configs) { described_class.new(declaratives_topics, existing_topics_names) }

  let(:existing_topics_names) { [existing_topic.name] }
  let(:declaratives_topics) { [existing_topic] }
  let(:existing_topic) { Karafka::Declaratives::Topic.new(generate_topic_name) }

  before { Karafka::Admin.create_topic(existing_topic.name, 1, 1) }

  context "when an existing topic has only configs the cluster knows" do
    before { existing_topic.details = { "retention.ms": 86_400_000, "log.retention.bytes": 1_000 } }

    it { expect(unknown_configs.call).to eq({}) }
  end

  context "when an existing topic has configs the cluster does not know" do
    before { existing_topic.details = { "retention.ms": 86_400_000, "retention.msx": 86_400_000 } }

    it "expect to return only the unknown configs, as strings" do
      expect(unknown_configs.call).to eq(existing_topic => { "retention.msx" => "86400000" })
    end
  end

  context "when a topic with unknown configs does not exist in the cluster" do
    let(:missing_topic) { Karafka::Declaratives::Topic.new(generate_topic_name) }
    let(:declaratives_topics) { [existing_topic, missing_topic] }

    before { missing_topic.details = { "retention.ms": 1, "retention.msx": 1 } }

    it { expect(unknown_configs.call).to eq(missing_topic => { "retention.msx" => "1" }) }
  end

  context "when only topics that do not exist in the cluster are declared" do
    let(:missing_topic) { Karafka::Declaratives::Topic.new(generate_topic_name) }
    let(:declaratives_topics) { [missing_topic] }

    before { missing_topic.details = { "retention.ms": 1, "retention.msx": 1 } }

    it { expect(unknown_configs.call).to eq(missing_topic => { "retention.msx" => "1" }) }
  end

  context "when the cluster has no topics" do
    let(:existing_topics_names) { [] }

    before { existing_topic.details = { "retention.msx": 1 } }

    it { expect(unknown_configs.call).to eq({}) }
  end

  context "when no existing topic has configs" do
    it { expect(unknown_configs.call).to eq({}) }
  end
end
