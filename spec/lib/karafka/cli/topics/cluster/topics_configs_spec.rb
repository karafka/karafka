# frozen_string_literal: true

RSpec.describe_current do
  subject(:topics_configs) { described_class.new(topic_name) }

  let(:topic_name) { generate_topic_name }

  before { Karafka::Admin.create_topic(topic_name, 1, 1) }

  describe "#names" do
    it { expect(topics_configs.names).to include("retention.ms", "cleanup.policy") }
    it { expect(topics_configs.names).not_to include("log.retention.bytes") }
  end

  describe "#names_with_synonyms" do
    it { expect(topics_configs.names_with_synonyms).to include("retention.ms", "cleanup.policy") }
    it { expect(topics_configs.names_with_synonyms).to include("log.retention.bytes") }
  end
end
