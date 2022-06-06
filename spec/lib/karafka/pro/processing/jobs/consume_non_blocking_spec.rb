# frozen_string_literal: true

require 'karafka/pro/processing/jobs/consume_non_blocking'

RSpec.describe_current do
  subject(:job) { described_class.new(executor, messages) }

  let(:executor) { build(:processing_executor) }
  let(:messages) { [rand] }
  let(:time_now) { Time.now }

  it { expect(job.non_blocking?).to eq(false) }
  it { expect(described_class).to be < ::Karafka::Processing::Jobs::Consume }

  describe '#prepare' do
    before do
      allow(Time).to receive(:now).and_return(time_now)
      allow(executor).to receive(:prepare)
    end

    it 'expect to run prepare on the executor with time and messages' do
      job.prepare
      expect(executor).to have_received(:prepare).with(messages, time_now)
    end

    it 'expect to mark this job as non blocking after it is done with preparation' do
      expect { job.prepare }.to change(job, :non_blocking?).from(false).to(true)
    end
  end
end
