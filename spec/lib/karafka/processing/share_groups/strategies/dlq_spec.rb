# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer) do
    instance = Class.new(Karafka::ShareConsumer).new
    instance.singleton_class.include(described_class)
    instance.client = client
    instance.coordinator = coordinator
    instance.producer = producer
    instance.messages = messages
    instance
  end

  let(:client) do
    instance_double(
      Karafka::Connection::ShareGroups::Client,
      mark_as_accepted: true,
      mark_as_released: true,
      mark_as_rejected: true,
      commit: nil
    )
  end

  let(:producer) { instance_double(WaterDrop::Producer, produce_async: nil, produce_sync: nil) }
  let(:topic) { build(:routing_share_topic).tap { |t| t.dead_letter_queue(topic: "dlq", max_retries: 2) } }
  let(:coordinator) { Karafka::Processing::ShareGroups::Coordinator.new(topic, 0) }
  let(:message) { build(:messages_message, raw_payload: "payload") }
  let(:messages) { Karafka::Messages::Builders::Messages.call([message], topic, 0, Time.now) }

  before { message.metadata.delivery_count = delivery_count }

  describe "#handle_after_consume" do
    context "when consumption failed and retries are not exhausted" do
      let(:delivery_count) { 2 }

      before do
        coordinator.failure!(consumer, StandardError.new)
        consumer.handle_after_consume
      end

      it { expect(producer).not_to have_received(:produce_async) }
      it { expect(client).not_to have_received(:mark_as_rejected) }
      it { expect(client).to have_received(:mark_as_released).with(message) }
    end

    context "when consumption failed and retries are exhausted" do
      let(:delivery_count) { 3 }

      before do
        coordinator.failure!(consumer, StandardError.new)
        consumer.handle_after_consume
      end

      it "dispatches the raw payload to the dlq topic" do
        expect(producer).to have_received(:produce_async).with(topic: "dlq", payload: "payload")
      end

      it { expect(client).to have_received(:mark_as_rejected).with(message) }
    end

    context "when the dlq topic is false" do
      let(:delivery_count) { 3 }
      let(:topic) do
        build(:routing_share_topic).tap { |t| t.dead_letter_queue(topic: false, max_retries: 2) }
      end

      before do
        coordinator.failure!(consumer, StandardError.new)
        consumer.handle_after_consume
      end

      it { expect(producer).not_to have_received(:produce_async) }
      it { expect(client).to have_received(:mark_as_rejected).with(message) }
    end

    context "when the exhausted record was already acknowledged by the consumer" do
      let(:delivery_count) { 3 }

      before do
        consumer.mark_as_accepted(message)
        coordinator.failure!(consumer, StandardError.new)
        consumer.handle_after_consume
      end

      it { expect(producer).not_to have_received(:produce_async) }
      it { expect(client).not_to have_received(:mark_as_rejected) }
    end

    context "when the failure is process-critical" do
      let(:delivery_count) { 3 }

      before do
        coordinator.failure!(consumer, SignalException.new("TERM"))
        consumer.handle_after_consume
      end

      it { expect(producer).not_to have_received(:produce_async) }
      it { expect(client).to have_received(:mark_as_released).with(message) }
    end

    context "when consumption succeeded" do
      let(:delivery_count) { 3 }

      before do
        coordinator.success!(consumer)
        consumer.handle_after_consume
      end

      it { expect(producer).not_to have_received(:produce_async) }
      it { expect(client).to have_received(:mark_as_released).with(message) }
    end
  end
end
