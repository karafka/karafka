# frozen_string_literal: true

RSpec.describe_current do
  subject(:pool) { described_class.new(jobs_queue) }

  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }
  let(:concurrency) { Karafka::App.config.concurrency }

  after do
    jobs_queue.close
    pool.join
  end

  describe "#size" do
    it "returns the configured concurrency" do
      expect(pool.size).to eq(concurrency)
    end
  end

  describe "#scale" do
    let(:up_events) do
      events = []
      Karafka.monitor.subscribe("worker.scaling.up") { |event| events << event }
      events
    end

    let(:down_events) do
      events = []
      Karafka.monitor.subscribe("worker.scaling.down") { |event| events << event }
      events
    end

    before do
      up_events
      down_events
    end

    it "grows when target is above current" do
      initial = pool.size
      pool.scale(initial + 3)
      expect(pool.size).to eq(initial + 3)
    end

    it "emits worker.scaling.up event with correct payload" do
      initial = pool.size
      pool.scale(initial + 2)
      last_event = up_events.last
      expect(last_event.payload[:from]).to eq(initial)
      expect(last_event.payload[:to]).to eq(initial + 2)
      expect(last_event.payload[:workers_pool]).to eq(pool)
    end

    it "shrinks when target is below current" do
      initial = pool.size
      allow(jobs_queue).to receive(:<<).and_call_original
      pool.scale(initial - 2)
      expect(jobs_queue).to have_received(:<<).with(nil).exactly(2).times
    end

    it "emits worker.scaling.down event with correct payload" do
      initial = pool.size
      allow(jobs_queue).to receive(:<<).and_call_original
      pool.scale(initial - 2)
      expect(down_events.size).to eq(1)
      event = down_events.first
      expect(event.payload[:from]).to eq(initial)
      expect(event.payload[:to]).to eq(initial - 2)
    end

    it "does nothing when target equals current" do
      initial = pool.size
      allow(jobs_queue).to receive(:<<).and_call_original
      pool.scale(initial)
      expect(pool.size).to eq(initial)
    end

    it "enforces minimum of 1" do
      allow(jobs_queue).to receive(:<<).and_call_original
      initial = pool.size
      pool.scale(0)
      expect(jobs_queue).to have_received(:<<).with(nil).exactly(initial - 1).times
    end

    it "never shrinks below 1" do
      pool.scale(1)
      sleep(0.2)
      expect(pool.size).to be >= 1

      down_events.clear
      pool.scale(0)
      # Already at 1, shrink is a no-op
      expect(down_events).to be_empty
    end
  end

  describe "#deregister" do
    it "removes the worker from the pool" do
      worker = pool.alive.first
      initial = pool.size
      pool.deregister(worker)
      expect(pool.size).to eq(initial - 1)
    end
  end

  describe "#join" do
    it "waits for all workers to finish" do
      jobs_queue.close
      expect { pool.join }.not_to raise_error
    end
  end
end
