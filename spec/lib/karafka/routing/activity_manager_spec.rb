# frozen_string_literal: true

RSpec.describe_current do
  subject(:manager) { described_class.new }

  describe '#include and #active?' do
    context 'when trying to include something of an invalid type' do
      let(:expected_error) { ::Karafka::Errors::UnsupportedCaseError }

      it { expect { manager.include('na', 1) }.to raise_error(expected_error) }
    end

    context 'when nothing is included and nothin is excluded' do
      pending
    end

    context 'when topic is in the included once' do
      pending
    end
  end

  describe '#exclude and #active?' do
    context 'when trying to exclude something of an invalid type' do
      let(:expected_error) { ::Karafka::Errors::UnsupportedCaseError }

      it { expect { manager.exclude('na', 1) }.to raise_error(expected_error) }
    end

    context 'when topic is in the excluded only' do
      pending
    end

    context 'when topic is in the included and excluded at the same time' do
      pending
    end
  end

  describe '#to_h' do
    pending
  end

  describe '#clear' do
    pending
  end
end
