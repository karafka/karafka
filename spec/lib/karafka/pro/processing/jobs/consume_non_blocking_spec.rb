# frozen_string_literal: true

require 'karafka/pro/processing/jobs/consume_non_blocking'

RSpec.describe_current do
  subject(:job) { described_class.new(executor, messages, coordinator) }

  let(:executor) { build(:processing_executor) }
  let(:messages) { [rand] }
  let(:coordinator) { build(:processing_coordinator) }
  let(:time_now) { Time.now }

  it { expect(job.non_blocking?).to eq(false) }
  it { expect(described_class).to be < ::Karafka::Processing::Jobs::Consume }

  describe '#before_call' do
    before do
      allow(Time).to receive(:now).and_return(time_now)
      allow(executor).to receive(:before_consume)
    end

    it 'expect to run before_consume on the executor with time and messages' do
      job.before_call
      expect(executor).to have_received(:before_consume).with(messages, time_now, coordinator)
    end

    it 'expect to mark this job as non blocking after it is done with preparation' do
      expect { job.before_call }.to change(job, :non_blocking?).from(false).to(true)
    end
  end
end
