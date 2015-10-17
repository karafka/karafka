require 'spec_helper'

RSpec.describe Karafka::Errors do
  describe 'BaseError' do
    subject { described_class::BaseError }

    specify { expect(subject).to be < StandardError }
  end

  describe 'NonMatchingTopicError' do
    subject { described_class::NonMatchingTopicError }

    specify { expect(subject).to be < described_class::BaseError }
  end

  describe 'PerformMethodNotDefined' do
    subject { described_class::PerformMethodNotDefined }

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
end
