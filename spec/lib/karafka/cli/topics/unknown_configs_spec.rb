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

  context "when a topic that does not exist in the cluster uses a synonym config name" do
    let(:missing_topic) { Karafka::Declaratives::Topic.new(generate_topic_name) }
    let(:declaratives_topics) { [existing_topic, missing_topic] }

    before do
      existing_topic.details = { "log.retention.bytes": 1_000 }
      missing_topic.details = { "retention.ms": 1, "log.retention.bytes": 1_000 }
    end

    it "expect to report the synonym only for the topic that would be created" do
      expect(unknown_configs.call).to eq(missing_topic => { "log.retention.bytes" => "1000" })
    end
  end

  context "when an existing topic uses a synonym config name and is checked as new" do
    subject(:unknown_configs) do
      described_class.new(declaratives_topics, existing_topics_names, as_new: true)
    end

    before { existing_topic.details = { "retention.ms": 1, "log.retention.bytes": 1_000 } }

    it { expect(unknown_configs.call).to eq(existing_topic => { "log.retention.bytes" => "1000" }) }
  end

  context "when only new topics are declared and describing another topic is not allowed" do
    let(:missing_topic) { Karafka::Declaratives::Topic.new(generate_topic_name) }
    let(:declaratives_topics) { [missing_topic] }
    # Topic authorization failed
    let(:error) { Rdkafka::RdkafkaError.new(29) }
    let(:new_topics_configs) { instance_double(Karafka::Cli::Topics::Cluster::NewTopicsConfigs) }

    before do
      missing_topic.details = { "retention.ms": 1, "retention.msx": 1 }
      allow(Karafka::Admin::Configs).to receive(:describe).and_raise(error)
    end

    it { expect(unknown_configs.call).to eq(missing_topic => { "retention.msx" => "1" }) }

    it "expect not to create the topic" do
      unknown_configs.call
      topics_names = Karafka::Admin.cluster_info.topics.map { |topic| topic[:topic_name] }
      expect(topics_names).not_to include(missing_topic.name)
    end

    context "when validating the creation of topics is not allowed either" do
      before do
        allow(Karafka::Cli::Topics::Cluster::NewTopicsConfigs)
          .to receive(:new)
          .and_return(new_topics_configs)

        allow(new_topics_configs).to receive(:unknown).and_raise(error)
      end

      it { expect(unknown_configs.call).to eq({}) }
    end

    context "when we are not allowed to create only one of the topics" do
      let(:denied_topic) { Karafka::Declaratives::Topic.new(generate_topic_name) }
      let(:declaratives_topics) { [denied_topic, missing_topic] }

      before do
        denied_topic.details = { "retention.ms": 1 }

        allow(Karafka::Admin).to receive(:with_admin).and_wrap_original do |original, &block|
          original.call do |admin|
            allow(admin).to receive(:create_topic).and_call_original
            allow(admin)
              .to receive(:create_topic)
              .with(denied_topic.name, any_args)
              .and_raise(error)

            block.call(admin)
          end
        end
      end

      it { expect(unknown_configs.call).to eq(missing_topic => { "retention.msx" => "1" }) }
    end

    context "when validating the creation of topics fails for a different reason" do
      let(:other_error) { Rdkafka::RdkafkaError.new(Rdkafka::Bindings::RD_KAFKA_RESP_ERR__FATAL) }

      before do
        allow(Karafka::Cli::Topics::Cluster::NewTopicsConfigs)
          .to receive(:new)
          .and_return(new_topics_configs)

        allow(new_topics_configs).to receive(:unknown).and_raise(other_error)
      end

      it { expect { unknown_configs.call }.to raise_error(other_error) }
    end
  end

  context "when describing another topic fails for a different reason" do
    let(:missing_topic) { Karafka::Declaratives::Topic.new(generate_topic_name) }
    let(:declaratives_topics) { [missing_topic] }
    let(:error) { Rdkafka::RdkafkaError.new(Rdkafka::Bindings::RD_KAFKA_RESP_ERR__FATAL) }

    before do
      missing_topic.details = { "retention.msx": 1 }
      allow(Karafka::Admin::Configs).to receive(:describe).and_raise(error)
    end

    it { expect { unknown_configs.call }.to raise_error(error) }
  end

  context "when the cluster has no topics" do
    let(:existing_topics_names) { [] }
    let(:missing_topic) { Karafka::Declaratives::Topic.new(generate_topic_name) }
    let(:other_missing_topic) { Karafka::Declaratives::Topic.new(generate_topic_name) }
    let(:declaratives_topics) { [missing_topic, other_missing_topic] }

    before do
      missing_topic.details = { "retention.ms": 1, "retention.msx": 1, "log.retention.bytes": 1 }
      other_missing_topic.details = { "retention.ms": 1 }
    end

    it "expect to report unknown configs and synonyms of the topics that would be created" do
      expect(unknown_configs.call).to eq(
        missing_topic => { "retention.msx" => "1", "log.retention.bytes" => "1" }
      )
    end
  end

  context "when no existing topic has configs" do
    it { expect(unknown_configs.call).to eq({}) }
  end
end
