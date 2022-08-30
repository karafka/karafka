# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor, messages, coordinator) }

  let(:executor) { build(:processing_executor) }
  let(:messages) { [rand] }
  let(:coordinator) { build(:processing_coordinator) }

  it { expect(job.non_blocking?).to eq(false) }

  describe '#before_enqueue' do
    before do
      allow(executor).to receive(:before_enqueue)
      job.before_enqueue
    end

    it 'expect to run before_enqueue on the executor with time and messages' do
      expect(executor).to have_received(:before_enqueue).with(messages, coordinator)
    end
  end

  describe '#before_call' do
    before do
      allow(executor).to receive(:before_consume)
      job.before_call
    end

    it 'expect to run before_consume on the executor' do
      expect(executor).to have_received(:before_consume).with(no_args)
    end
  end

  describe '#call' do
    before do
      allow(executor).to receive(:consume)
      job.call
    end

    it 'expect to run consume' do
      expect(executor).to have_received(:consume)
    end
  end

  describe '#after_call' do
    before do
      allow(executor).to receive(:after_consume)
      job.after_call
    end

    it 'expect to run after_consume on the executor' do
      expect(executor).to have_received(:after_consume).with(no_args)
    end
  end
end
