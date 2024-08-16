# frozen_string_literal: true

RSpec.describe_current do
  describe 'BaseError' do
    subject(:error) { described_class::BaseError }

    specify { expect(error).to be < ::Karafka::Errors::BaseError }
  end
end
