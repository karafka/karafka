# frozen_string_literal: true

RSpec.describe_current do
  subject(:buffer) { described_class.new }

  describe '#find_or_create' do
    context 'when coordinator did not exist' do
      it 'expect to create one' do
        expect(buffer.find_or_create(0, 1)).to be_a(Karafka::Processing::Coordinator)
      end
    end

    context 'when coordinator did exist' do
      let(:existing) { buffer.find_or_create(0, 1) }

      before { existing }

      it 'expect to use instance we already have' do
        expect(buffer.find_or_create(0, 1)).to eq(existing)
      end
    end
  end

  describe '#resume' do
    context 'when nothing to resume' do
      it { expect { |block| buffer.resume(&block) }.not_to yield_with_args }
    end

    context 'when partition to resume' do
      let(:existing) { buffer.find_or_create(0, 1) }

      before do
        existing.pause_tracker.pause
        existing.pause_tracker.expire
      end

      it 'expect to delegate to pauses manager' do
        expect { |block| buffer.resume(&block) }.to yield_with_args(0, 1)
      end
    end
  end

  describe '#revoke' do
    let(:existing) { buffer.find_or_create(0, 1) }

    before do
      existing
      buffer.revoke(0, 1)
    end

    it 'expect to remove coordinator' do
      expect(buffer.find_or_create(0, 1)).not_to eq(existing)
    end
  end
end
