# frozen_string_literal: true

RSpec.describe_current do
  describe 'PrivateKeyNotFound' do
    subject(:error) { described_class::PrivateKeyNotFound }

    specify { expect(error).to be < ::Karafka::Errors::BaseError }
  end
end
