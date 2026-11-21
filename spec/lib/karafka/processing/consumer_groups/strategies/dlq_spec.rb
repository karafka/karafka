# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer) do
    instance = Karafka::BaseConsumer.new
    instance.coordinator = coordinator
    instance.producer = producer
    instance.singleton_class.include(described_class)
    instance
  end

  let(:coordinator) { build(:processing_coordinator) }
  let(:producer) { instance_double(WaterDrop::Producer, produce_async: true) }
  let(:message) { build(:messages_message, raw_payload: "broken") }
  let(:expected_dispatch) { { topic: "dlq-topic", payload: "broken" } }

  before { coordinator.topic.dead_letter_queue(topic: "dlq-topic") }

  it { expect(described_class::FEATURES).to eq(%i[dead_letter_queue]) }

  describe "#dispatch_to_dead_letter_queue" do
    it "expect to dispatch the raw payload to the DLQ topic" do
      consumer.dispatch_to_dead_letter_queue(message)

      expect(producer).to have_received(:produce_async).with(expected_dispatch)
    end
  end

  describe "#dispatch_to_dlq" do
    it "expect to keep dispatching to the DLQ topic under the deprecated name" do
      consumer.dispatch_to_dlq(message)

      expect(producer).to have_received(:produce_async).with(expected_dispatch)
    end
  end
end
