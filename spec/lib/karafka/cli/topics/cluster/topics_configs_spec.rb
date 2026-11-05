# frozen_string_literal: true

RSpec.describe_current do
  subject(:topics_configs) { described_class.new(topic_name) }

  let(:topic_name) { generate_topic_name }

  before { Karafka::Admin.create_topic(topic_name, 1, 1) }

  describe "#names" do
    it { expect(topics_configs.names).to include("retention.ms", "cleanup.policy") }
    it { expect(topics_configs.names).to include("log.retention.bytes") }
  end
end
