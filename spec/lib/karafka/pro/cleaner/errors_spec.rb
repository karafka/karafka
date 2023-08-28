# frozen_string_literal: true

RSpec.describe_current do
  describe 'BaseError' do
    subject(:error) { described_class::BaseError }

    specify { expect(error).to be < ::Karafka::Errors::BaseError }
  end

  describe 'MessageCleanedError' do
    subject(:error) { described_class::MessageCleanedError }

    specify { expect(error).to be < described_class::BaseError }
  end
end
