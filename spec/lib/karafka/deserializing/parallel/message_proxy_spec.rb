# frozen_string_literal: true

RSpec.describe_current do
  subject(:proxy) { described_class.new(raw_payload: payload) }

  let(:payload) { "test payload" }

  describe "#raw_payload" do
    it "returns the raw payload" do
      expect(proxy.raw_payload).to eq(payload)
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(proxy).to be_frozen
    end
  end
end
