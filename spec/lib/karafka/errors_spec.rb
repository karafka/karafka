require 'spec_helper'

RSpec.describe Karafka::Errors do
  describe 'BaseError' do
    subject { described_class::BaseError }

    specify { expect(subject).to be < StandardError }
  end

  describe 'ParserError' do
    subject { described_class::ParserError }

    specify { expect(subject).to be < described_class::BaseError }
  end

  describe 'NonMatchingRouteError' do
    subject { described_class::NonMatchingRouteError }

    specify { expect(subject).to be < described_class::BaseError }
  end

  describe 'DuplicatedGroupError' do
    subject { described_class::DuplicatedGroupError }

    specify { expect(subject).to be < described_class::BaseError }
  end

  describe 'DuplicatedTopicError' do
    subject { described_class::DuplicatedTopicError }

    specify { expect(subject).to be < described_class::BaseError }
  end

  describe 'InvalidTopicName' do
    subject { described_class::InvalidTopicName }

    specify { expect(subject).to be < described_class::BaseError }
  end

  describe 'InvalidGroupName' do
    subject { described_class::InvalidGroupName }

    specify { expect(subject).to be < described_class::BaseError }
  end

  describe 'BaseWorkerDescentantMissing' do
    subject { described_class::BaseWorkerDescentantMissing }

    specify { expect(subject).to be < described_class::BaseError }
  end
end
