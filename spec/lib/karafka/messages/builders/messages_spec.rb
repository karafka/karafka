# frozen_string_literal: true

RSpec.describe_current do
  let(:message1) { build(:kafka_fetched_message) }
  let(:message2) { build(:kafka_fetched_message) }
  let(:kafka_messages) { [message1, message2] }
  let(:routing_topic) { build(:routing_topic) }
  let(:received_at) { Time.new }

  describe '#call' do
    subject(:result) { described_class.call(kafka_messages, routing_topic, received_at) }

    it { is_expected.to be_a(Karafka::Messages::Messages) }
  end
end
