# frozen_string_literal: true

RSpec.describe_current do
  describe 'PrivateKeyNotFoundError' do
    subject(:error) { described_class::PrivateKeyNotFoundError }

    specify { expect(error).to be < ::Karafka::Errors::BaseError }
  end
end
