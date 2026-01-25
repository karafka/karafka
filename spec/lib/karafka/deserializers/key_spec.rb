# frozen_string_literal: true

RSpec.describe_current do
  subject(:deserializer) { described_class.new }

  let(:metadata) { Karafka::Messages::Metadata.new(raw_key: "test_key") }

  describe "#call" do
    it "returns the raw_key from the metadata" do
      expect(deserializer.call(metadata)).to eq("test_key")
    end
  end
end
