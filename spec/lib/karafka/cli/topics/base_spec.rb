# frozen_string_literal: true

RSpec.describe_current do
  subject(:topics) { described_class.new(kafka: kafka) }

  let(:default_servers) { Karafka::App.config.kafka.fetch(:"bootstrap.servers") }
  let(:custom_servers) { "other:9092" }
  let(:kafka) { { "bootstrap.servers" => custom_servers } }
  let(:default_topic) { Karafka::Declaratives::Topic.new(:default) }
  let(:custom_topic) do
    Karafka::Declaratives::Topic.new(:custom).tap do |topic|
      topic.bootstrap_servers = custom_servers
    end
  end

  before do
    allow(Karafka::App.declaratives)
      .to receive(:topics)
      .and_return([default_topic, custom_topic])
  end

  it "selects only topics belonging to the custom cluster" do
    expect(topics.send(:declaratives_routing_topics)).to eq([custom_topic])
  end

  context "without custom Kafka configuration" do
    let(:kafka) { {} }

    it "keeps standalone topics on the default cluster" do
      custom_topic.bootstrap_servers = "#{default_servers}-other"

      expect(topics.send(:declaratives_routing_topics)).to eq([default_topic])
    end

    it "preserves the class-level Admin clients" do
      expect(topics.send(:admin)).to equal(Karafka::Admin)
      expect(topics.send(:configs_admin)).to equal(Karafka::Admin::Configs)
    end
  end

  it "uses the custom configuration for Admin clients" do
    expect(Karafka::Admin).to receive(:new).with(kafka: kafka).and_call_original
    expect(Karafka::Admin::Configs).to receive(:new).with(kafka: kafka).and_call_original

    topics.send(:admin)
    topics.send(:configs_admin)
  end
end
