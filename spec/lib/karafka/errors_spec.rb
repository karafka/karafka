# frozen_string_literal: true

RSpec.describe Karafka::Errors do
  describe 'BaseError' do
    subject(:error) { described_class::BaseError }

    specify { expect(error).to be < StandardError }
  end

  describe 'ParserError' do
    subject(:error) { described_class::ParserError }

    specify { expect(error).to be < described_class::BaseError }
  end

  describe 'NonMatchingRouteError' do
    subject(:error) { described_class::NonMatchingRouteError }

    specify { expect(error).to be < described_class::BaseError }
  end

  describe 'BaseWorkerDescentantMissing' do
    subject(:error) { described_class::BaseWorkerDescentantMissing }

    specify { expect(error).to be < described_class::BaseError }
  end

  describe 'InvalidConfiguration' do
    subject(:error) { described_class::InvalidConfiguration }

    specify { expect(error).to be < described_class::BaseError }
  end
end
