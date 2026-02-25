# frozen_string_literal: true

RSpec.describe_current do
  subject(:deserializer) { described_class.new }

  let(:metadata) { Karafka::Messages::Metadata.new(raw_key: "test_key") }

  describe "#initialize" do
    it "inherits from Base" do
      expect(described_class.superclass).to eq(Karafka::Deserializing::Deserializers::Base)
    end

    it "is frozen for Ractor shareability" do
      expect(deserializer).to be_frozen
    end
  end

  describe "#call" do
    it "returns the raw_key from the metadata" do
      expect(deserializer.call(metadata)).to eq("test_key")
    end
  end
end
