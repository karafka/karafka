# frozen_string_literal: true

RSpec.describe_current do
  subject(:worker) { described_class.new(queue).tap(&:async_call) }

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
        allow(job).to receive(:before_call)
        allow(job).to receive(:call)
        allow(job).to receive(:after_call)
        allow(queue).to receive(:tick)

        queue << job
        # Force the background job work, so we can validate the expectation as the thread will
        # execute correctly the given job
        Thread.pass
        sleep(0.05)
      end

      it { expect(queue).not_to have_received(:tick) }
      it { expect(job).to have_received(:before_call).with(no_args) }
      it { expect(job).to have_received(:call).with(no_args) }
      it { expect(job).to have_received(:after_call).with(no_args) }
      it { expect(queue).to have_received(:complete).with(job) }
    end

    context 'when it is a non-closing, non-blocking job' do
      let(:job) { OpenStruct.new(group_id: 1, id: 1, call: true, non_blocking?: true) }

      before do
        allow(job).to receive(:before_call)
        allow(job).to receive(:call)
        allow(job).to receive(:after_call)
        allow(queue).to receive(:tick)

        queue << job
        # Force the background job work, so we can validate the expectation as the thread will
        # execute correctly the given job
        Thread.pass
        sleep(0.05)
      end

      it { expect(queue).to have_received(:tick).with(job.group_id) }
      it { expect(job).to have_received(:before_call).with(no_args) }
      it { expect(job).to have_received(:call).with(no_args) }
      it { expect(job).to have_received(:after_call).with(no_args) }
      it { expect(queue).to have_received(:complete).with(job) }
    end

    context 'when an error occurs in the worker' do
      let(:job) { OpenStruct.new(group_id: 1, id: 1, call: true) }

      let(:detected_errors) do
        errors = []
        Karafka.monitor.subscribe('error.occurred') { |occurred| errors << occurred }
        errors
      end

      let(:completions) do
        completions = []
        Karafka.monitor.subscribe('worker.completed') { |event| completions << event }
        completions
      end

      before do
        allow(job).to receive(:before_call).and_raise(StandardError)

        detected_errors
        completions

        queue << job
        Thread.pass
        sleep(0.05)
      end

      it 'expect to instrument on it' do
        expect(detected_errors[0].id).to eq('error.occurred')
        expect(detected_errors[0].payload[:type]).to eq('worker.process.error')
      end

      it 'expect to publish completion even despite error' do
        expect(completions[0].id).to eq('worker.completed')
      end
    end
  end
end
