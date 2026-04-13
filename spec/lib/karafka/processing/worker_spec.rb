# frozen_string_literal: true

RSpec.describe_current do
  subject(:worker) do
    described_class.new(queue, pool).tap do |worker|
      worker.async_call("spec.worker")
    end
  end

  let(:queue) { Karafka::Processing::JobsQueue.new }
  let(:pool) { instance_double(Karafka::Processing::WorkersPool, size: 5, deregister: nil) }

  # Since this worker has a background thread, we need to initialize the worker before running
  # any specs
  before do
    queue.pool = pool
    worker
  end

  after { worker.terminate }

  describe "#join" do
    before { queue.close }

    it { expect { worker.join }.not_to raise_error }
  end

  describe "#terminate" do
    it "expect to kill the underlying thread" do
      expect(worker.alive?).to be(true)
      worker.terminate
      worker.join
      expect(worker.alive?).to be(false)
    end
  end

  describe "#process" do
    before { allow(queue).to receive(:complete) }

    context "when the job is a queue closing operation" do
      before { queue.close }

      it { expect(queue).not_to have_received(:complete) }
    end

    context "when it is a non-closing, blocking job" do
      let(:job) { OpenStruct.new(group_id: 1, id: 1, call: true, wrap: true) }

      before do
        allow(job).to receive(:wrap).and_yield
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

    context "when it is a non-closing, non-blocking job" do
      let(:job) { OpenStruct.new(group_id: 1, id: 1, call: true, non_blocking?: true) }

      before do
        allow(job).to receive(:wrap).and_yield
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

    context "when nil is pushed to the queue (pool downscaling)" do
      let(:downscale_queue) { Karafka::Processing::JobsQueue.new }
      let(:downscale_pool) { instance_double(Karafka::Processing::WorkersPool, size: 5) }

      let(:worker_with_pool) do
        described_class.new(downscale_queue, downscale_pool).tap do |w|
          w.async_call("spec.worker.downscale")
        end
      end

      before do
        allow(downscale_pool).to receive(:deregister)
        allow(downscale_queue).to receive(:complete)
        downscale_queue.pool = downscale_pool
        worker_with_pool
      end

      after do
        downscale_queue.close
        worker_with_pool.join
      end

      it "deregisters from the pool and stops the loop" do
        downscale_queue << nil
        sleep(0.1)

        expect(downscale_pool).to have_received(:deregister).with(worker_with_pool)
        expect(downscale_queue).not_to have_received(:complete)
        expect(worker_with_pool.alive?).to be(false)
      end
    end

    context "when an error occurs in the worker" do
      let(:job) { OpenStruct.new(group_id: 1, id: 1, call: true) }

      let(:detected_errors) do
        errors = []
        Karafka.monitor.subscribe("error.occurred") { |occurred| errors << occurred }
        errors
      end

      let(:completions) do
        completions = []
        Karafka.monitor.subscribe("worker.completed") { |event| completions << event }
        completions
      end

      before do
        allow(job).to receive(:wrap).and_yield
        allow(job).to receive(:before_call).and_raise(StandardError)

        detected_errors
        completions

        queue << job
        Thread.pass
        sleep(0.05)
      end

      it "expect to instrument on it" do
        expect(detected_errors[0].id).to eq("error.occurred")
        expect(detected_errors[0].payload[:type]).to eq("worker.process.error")
      end

      it "expect to publish completion even despite error" do
        expect(completions[0].id).to eq("worker.completed")
      end
    end
  end
end
