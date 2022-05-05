# frozen_string_literal: true

RSpec.describe_current do
  subject(:worker) { described_class.new(queue) }

  let(:queue) { Karafka::Processing::JobsQueue.new }

  # Since this worker has a background thread, we need to initialize the worker before running
  # any specs
  before { worker }

  describe '#join' do
    before { queue.close }

    it { expect { worker.join }.not_to raise_error }
  end

  describe '#terminate' do
    it 'expect to kill the underlying thread' do
      expect(worker.alive?).to eq(true)
      worker.terminate
      worker.join
      expect(worker.alive?).to eq(false)
    end
  end

  describe '#process' do
    before { allow(queue).to receive(:complete) }

    context 'when the job is a queue closing operation' do
      before { queue.close }

      it { expect(queue).not_to have_received(:complete) }
    end

    context 'when it is a non-closing, blocking job' do
      let(:job) { OpenStruct.new(group_id: 1, id: 1, call: true) }

      before do
        allow(job).to receive(:prepare)
        allow(job).to receive(:call)
        allow(job).to receive(:teardown)
        allow(queue).to receive(:tick)

        queue << job
        # Force the background job work, so we can validate the expectation as the thread will
        # execute correctly the given job
        Thread.pass
        sleep(0.05)
      end

      it { expect(queue).not_to have_received(:tick) }
      it { expect(job).to have_received(:prepare).with(no_args) }
      it { expect(job).to have_received(:call).with(no_args) }
      it { expect(job).to have_received(:teardown).with(no_args) }
      it { expect(queue).to have_received(:complete).with(job) }
    end

    context 'when it is a non-closing, non-blocking job' do
      let(:job) { OpenStruct.new(group_id: 1, id: 1, call: true, non_blocking?: true) }

      before do
        allow(job).to receive(:prepare)
        allow(job).to receive(:call)
        allow(job).to receive(:teardown)
        allow(queue).to receive(:tick)

        queue << job
        # Force the background job work, so we can validate the expectation as the thread will
        # execute correctly the given job
        Thread.pass
        sleep(0.05)
      end

      it { expect(queue).to have_received(:tick).with(job.group_id) }
      it { expect(job).to have_received(:prepare).with(no_args) }
      it { expect(job).to have_received(:call).with(no_args) }
      it { expect(job).to have_received(:teardown).with(no_args) }
      it { expect(queue).to have_received(:complete).with(job) }
    end
  end
end
