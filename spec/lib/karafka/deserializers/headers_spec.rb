# frozen_string_literal: true

RSpec.describe_current do
  subject(:deserializer) { described_class.new }

  let(:metadata) { Karafka::Messages::Metadata.new(raw_headers: "test_headers") }

  describe "#call" do
    it "returns the raw_headers from the metadata" do
      expect(deserializer.call(metadata)).to eq("test_headers")
    end
  end
end
