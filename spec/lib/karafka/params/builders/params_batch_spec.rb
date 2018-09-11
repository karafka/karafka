# frozen_string_literal: true

RSpec.describe Karafka::Params::Builders::ParamsBatch do
  let(:message1) { build(:kafka_fetched_message) }
  let(:message2) { build(:kafka_fetched_message) }
  let(:kafka_messages) { [message1, message2] }
  let(:routing_topic) { build(:routing_topic) }

  describe '#from_kafka_messages' do
    subject(:result) { described_class.from_kafka_messages(kafka_messages, routing_topic) }

    it { is_expected.to be_a(Karafka::Params::ParamsBatch) }
  end
end
