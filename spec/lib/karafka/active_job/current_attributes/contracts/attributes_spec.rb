# frozen_string_literal: true

require "karafka/active_job/current_attributes"

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:data) { { attributes: { "user_id" => 1 } } }

  context "when attributes are a hash" do
    it { expect(contract.call(data)).to be_success }
  end

  context "when attributes are an empty hash" do
    before { data[:attributes] = {} }

    it { expect(contract.call(data)).to be_success }
  end

  context "when attributes are missing" do
    before { data.delete(:attributes) }

    it { expect(contract.call(data)).not_to be_success }
  end

  [nil, "x", [["user_id", 1]]].each do |attributes|
    context "when attributes are #{attributes.inspect}" do
      before { data[:attributes] = attributes }

      it { expect(contract.call(data)).not_to be_success }
    end
  end
end
