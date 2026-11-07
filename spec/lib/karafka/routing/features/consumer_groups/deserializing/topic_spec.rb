# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  let(:default_payload_deserializer) { Karafka::Deserializing::Deserializers::Payload }
  let(:default_key_deserializer) { Karafka::Deserializing::Deserializers::Key }
  let(:default_headers_deserializer) { Karafka::Deserializing::Deserializers::Headers }

  describe "#deserializing" do
    context "when using default deserializers" do
      it "sets default payload deserializer" do
        expect(topic.deserializing.payload).to be_a(default_payload_deserializer)
      end

      it "sets default key deserializer" do
        expect(topic.deserializing.key).to be_a(default_key_deserializer)
      end

      it "sets default headers deserializer" do
        expect(topic.deserializing.headers).to be_a(default_headers_deserializer)
      end
    end

    context "when custom deserializers are specified" do
      let(:custom_payload_deserializer) { rand }
      let(:custom_key_deserializer) { rand }
      let(:custom_headers_deserializer) { rand }

      before do
        topic.deserializing(
          payload: custom_payload_deserializer,
          key: custom_key_deserializer,
          headers: custom_headers_deserializer
        )
      end

      it "overrides default payload deserializer" do
        expect(topic.deserializing.payload).to eq(custom_payload_deserializer)
      end

      it "overrides default key deserializer" do
        expect(topic.deserializing.key).to eq(custom_key_deserializer)
      end

      it "overrides default headers deserializer" do
        expect(topic.deserializing.headers).to eq(custom_headers_deserializer)
      end
    end

    context "when only the payload deserializer is specified" do
      let(:custom_payload_deserializer) { rand }

      before { topic.deserializing(payload: custom_payload_deserializer) }

      it { expect(topic.deserializing.payload).to eq(custom_payload_deserializer) }
      it { expect(topic.deserializing.key).to be_a(default_key_deserializer) }
      it { expect(topic.deserializing.headers).to be_a(default_headers_deserializer) }
    end

    context "when nil deserializers are specified" do
      before { topic.deserializing(payload: nil, key: nil, headers: nil) }

      it { expect(topic.deserializing.payload).to be_nil }
      it { expect(topic.deserializing.key).to be_nil }
      it { expect(topic.deserializing.headers).to be_nil }
    end

    context "when deserializing was already set up" do
      let(:custom_payload_deserializer) { rand }

      before { topic.deserializing }

      it "keeps the first configuration" do
        first = topic.deserializing

        expect(topic.deserializing(payload: custom_payload_deserializer)).to be(first)
      end

      it "does not allocate on repeated calls" do
        skip("GC.stat has no total_allocated_objects on this Ruby") unless
          GC.stat.key?(:total_allocated_objects)

        topic.deserializing
        before = GC.stat(:total_allocated_objects)
        100.times { topic.deserializing }

        # Defaults built on each call would allocate 3 objects per call
        expect(GC.stat(:total_allocated_objects) - before).to be < 10
      end
    end
  end

  describe "#deserializers (backwards compatible alias)" do
    it "works as alias for deserializing" do
      expect(topic.deserializers).to eq(topic.deserializing)
    end

    it "can be used to configure deserializers" do
      custom = rand
      topic.deserializers(payload: custom)
      expect(topic.deserializing.payload).to eq(custom)
    end
  end

  describe "#deserializing?" do
    it "returns true" do
      expect(topic.deserializing?).to be true
    end
  end

  describe "#deserializers? (backwards compatible alias)" do
    it "works as alias for deserializing?" do
      expect(topic.deserializers?).to eq(topic.deserializing?)
    end
  end

  describe "#to_h" do
    it "includes deserializing in the topic hash" do
      expect(topic.to_h[:deserializing]).to eq(topic.deserializing.to_h)
    end
  end
end
