# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  let(:default_payload_deserializer) { Karafka::Deserializers::Payload }
  let(:default_key_deserializer) { Karafka::Deserializers::Key }
  let(:default_headers_deserializer) { Karafka::Deserializers::Headers }

  describe "#deserializers" do
    context "when using default deserializers" do
      it "sets default payload deserializer" do
        expect(topic.deserializers.payload).to be_a(default_payload_deserializer)
      end

      it "sets default key deserializer" do
        expect(topic.deserializers.key).to be_a(default_key_deserializer)
      end

      it "sets default headers deserializer" do
        expect(topic.deserializers.headers).to be_a(default_headers_deserializer)
      end
    end

    context "when custom deserializers are specified" do
      let(:custom_payload_deserializer) { rand }
      let(:custom_key_deserializer) { rand }
      let(:custom_headers_deserializer) { rand }

      before do
        topic.deserializers(
          payload: custom_payload_deserializer,
          key: custom_key_deserializer,
          headers: custom_headers_deserializer
        )
      end

      it "overrides default payload deserializer" do
        expect(topic.deserializers.payload).to eq(custom_payload_deserializer)
      end

      it "overrides default key deserializer" do
        expect(topic.deserializers.key).to eq(custom_key_deserializer)
      end

      it "overrides default headers deserializer" do
        expect(topic.deserializers.headers).to eq(custom_headers_deserializer)
      end
    end
  end

  describe "#deserializers?" do
    it "returns true" do
      expect(topic.deserializers?).to be true
    end
  end

  describe "#to_h" do
    it "includes deserializers in the topic hash" do
      expect(topic.to_h[:deserializers]).to eq(topic.deserializers.to_h)
    end
  end
end
