# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor, messages) }

  let(:executor) { build(:processing_executor) }
  let(:messages) { [rand] }

  it { expect(job.non_blocking?).to eq(false) }

  describe '#prepare' do
    before do
      allow(executor).to receive(:prepare)
      job.prepare
    end

    it 'expect to run prepare on the executor with time and messages' do
      expect(executor).to have_received(:prepare).with(messages)
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
end
