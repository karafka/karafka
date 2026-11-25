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

    context "when the message has both trace headers and other headers" do
      let(:message) do
        build(
          :messages_message,
          raw_payload: "broken",
          raw_headers: {
            "traceparent" => "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
            "tracestate" => "rojo=00f067aa0ba902b7",
            "other" => "value"
          }
        )
      end

      let(:expected_headers) do
        {
          "traceparent" => "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
          "tracestate" => "rojo=00f067aa0ba902b7"
        }
      end

      it "expect to copy only the trace headers" do
        consumer.dispatch_to_dead_letter_queue(message)

        expect(producer)
          .to have_received(:produce_async)
          .with(expected_dispatch.merge(headers: expected_headers))
      end
    end

    context "when the message has only the traceparent header" do
      let(:message) do
        build(
          :messages_message,
          raw_payload: "broken",
          raw_headers: { "traceparent" => "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01" }
        )
      end

      it "expect to copy only the traceparent header" do
        consumer.dispatch_to_dead_letter_queue(message)

        expect(producer).to have_received(:produce_async).with(
          expected_dispatch.merge(
            headers: { "traceparent" => "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01" }
          )
        )
      end
    end

    context "when the message has only headers other than the trace headers" do
      let(:message) do
        build(:messages_message, raw_payload: "broken", raw_headers: { "other" => "value" })
      end

      it "expect not to add any headers" do
        consumer.dispatch_to_dead_letter_queue(message)

        expect(producer).to have_received(:produce_async).with(expected_dispatch)
      end
    end
  end

  describe "#dispatch_to_dlq" do
    it "expect to keep dispatching to the DLQ topic under the older name" do
      consumer.dispatch_to_dlq(message)

      expect(producer).to have_received(:produce_async).with(expected_dispatch)
    end
  end
end
