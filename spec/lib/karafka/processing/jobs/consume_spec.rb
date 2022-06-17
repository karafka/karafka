# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor, messages) }

  let(:executor) { build(:processing_executor) }
  let(:messages) { [rand] }
  let(:time_now) { Time.now }

  it { expect(job.non_blocking?).to eq(false) }

  describe '#before_consume' do
    before do
      allow(Time).to receive(:now).and_return(time_now)
      allow(executor).to receive(:before_consume)
      job.before_call
    end

    it 'expect to run before_consume on the executor with time and messages' do
      expect(executor).to have_received(:before_consume).with(messages, time_now)
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
