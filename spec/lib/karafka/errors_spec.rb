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

  describe 'DuplicatedGroupError' do
    subject(:error) { described_class::DuplicatedGroupError }

    specify { expect(error).to be < described_class::BaseError }
  end

  describe 'DuplicatedTopicError' do
    subject(:error) { described_class::DuplicatedTopicError }

    specify { expect(error).to be < described_class::BaseError }
  end

  describe 'InvalidTopicName' do
    subject(:error) { described_class::InvalidTopicName }

    specify { expect(error).to be < described_class::BaseError }
  end

  describe 'InvalidGroupName' do
    subject(:error) { described_class::InvalidGroupName }

    specify { expect(error).to be < described_class::BaseError }
  end

  describe 'BaseWorkerDescentantMissing' do
    subject(:error) { described_class::BaseWorkerDescentantMissing }

    specify { expect(error).to be < described_class::BaseError }
  end
end
