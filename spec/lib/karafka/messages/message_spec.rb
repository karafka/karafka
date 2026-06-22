# frozen_string_literal: true

RSpec.describe_current do
  let(:base_params_class) { described_class }
  let(:headers) { { message_type: "test" } }
  let(:raw_key) { rand.to_s }

  describe "instance methods" do
    subject(:message) { base_params_class.new(raw_payload, metadata) }

    let(:deserializer) { ->(_) { 1 } }
    let(:metadata) do
      Karafka::Messages::Metadata.new.tap do |metadata|
        metadata["raw_key"] = raw_key
        metadata["deserializers"] = Karafka::Routing::Features::Deserializing::Config.new(
          payload: deserializer
        )
      end
    end

    describe "#deserialize!" do
      let(:raw_payload) { rand }

      context "when message payload is already deserialized" do
        before do
          message.payload
          allow(message).to receive(:deserialize)
        end

        it "expect not to deserialize again and return self" do
          expect(message.payload).to eq 1
          expect(message).not_to have_received(:deserialize)
        end
      end

      context "when message payload was not yet deserializeds" do
        let(:raw_payload) { double }
        let(:deserialized_payload) { { double => double } }

        before do
          allow(message)
            .to receive(:deserialize)
            .and_return(deserialized_payload)
        end

        it "expect to merge with deserialized data that is under payload key" do
          expect(message.payload).to eq deserialized_payload
        end

        it "expect to mark as deserialized" do
          message.payload
          expect(message.deserialized?).to be(true)
        end
      end

      context "when deserialization error occurs" do
        let(:payload) { double }
        let(:deserialized_payload) { { double => double } }

        before do
          allow(message)
            .to receive(:deserialize)
            .and_raise(Karafka::Errors::BaseError)

          begin
            message.payload
          rescue Karafka::Errors::BaseError
            false
          end
        end

        it "expect not to mark raw payload as deserialized" do
          expect(message.deserialized?).to be(false)
        end
      end
    end

    describe "#deserialize" do
      let(:deserializer) { double }
      let(:raw_payload) { double }

      context "when we are able to successfully deserialize" do
        let(:deserialized_payload) { { rand => rand } }

        before do
          allow(deserializer)
            .to receive(:call)
            .with(message)
            .and_return(deserialized_payload)
        end

        it "expect to return payload in a message key" do
          expect(message.send(:deserialize)).to eq deserialized_payload
        end
      end
    end

    describe "#tombstone?" do
      context "when the raw_key is present and raw_payload is nil" do
        let(:raw_key) { "some_key" }
        let(:raw_payload) { nil }

        it "returns true" do
          expect(message.tombstone?).to be true
        end
      end

      context "when the raw_key is present and raw_payload is not nil" do
        let(:raw_key) { "some_key" }
        let(:raw_payload) { "some_payload" }

        it "returns false" do
          expect(message.tombstone?).to be(false)
        end
      end

      context "when the raw_key is nil and raw_payload is nil" do
        let(:raw_key) { nil }
        let(:raw_payload) { nil }

        it "returns false" do
          expect(message.tombstone?).to be(false)
        end
      end

      context "when the raw_key is nil and raw_payload is not nil" do
        let(:raw_key) { nil }
        let(:raw_payload) { "some_payload" }

        it "returns false" do
          expect(message.tombstone?).to be(false)
        end
      end
    end
  end
end
