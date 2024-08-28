# frozen_string_literal: true

RSpec.describe_current do
  describe 'BaseError' do
    subject(:error) { described_class::BaseError }

    specify { expect(error).to be < ::Karafka::Errors::BaseError }
  end

  describe 'IncompatibleSchemaError' do
    subject(:error) { described_class::IncompatibleSchemaError }

    specify { expect(error).to be < described_class::BaseError }
  end
end
