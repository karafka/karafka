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

    context 'when it is not a closing job' do
      let(:job) { OpenStruct.new(group_id: 1, id: 1, call: true) }

      before do
        allow(job).to receive(:call)
        queue << job
        # Force the background job work, so we can validate the expectation as the thread will
        # execute correctly the given job
        Thread.pass
        sleep(0.05)
      end

      it { expect(job).to have_received(:call).with(no_args) }
      it { expect(queue).to have_received(:complete).with(job) }
    end
  end
end
