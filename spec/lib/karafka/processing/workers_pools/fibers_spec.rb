# frozen_string_literal: true

require "async"

RSpec.describe_current do
  subject(:pool) do
    pool = described_class.new
    pool.jobs_queue = jobs_queue
    pool.scale(concurrency)
    pool
  end

  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }
  let(:concurrency) { Karafka::App.config.workers.concurrency }

  # Job compatible with the Worker#process flow that records execution details
  let(:job_class) do
    Class.new do
      attr_reader :group_id, :id

      def initialize(group_id, id, events, duration)
        @group_id = group_id
        @id = id
        @events = events
        @duration = duration
        @finished = false
      end

      def wrap
        yield
      end

      def before_call
      end

      def call
        clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @events << [:start, @id, Thread.current.name, clock]
        sleep(@duration)
        clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @events << [:stop, @id, Thread.current.name, clock]
      end

      def after_call
      end

      def non_blocking?
        false
      end

      def finish!
        @finished = true
      end

      def finished?
        @finished
      end
    end
  end

  after do
    jobs_queue.close
    pool.join
  end

  # Bounded wait so a regression cannot hang the suite
  # @param max [Numeric] max seconds to wait
  def wait_until(max = 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + max

    until yield
      raise "wait_until timeout" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep(0.02)
    end
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

    it "reduces the live size once sentinels are picked up" do
      initial = pool.size
      pool.scale(initial - 2)

      # Workers deregister asynchronously after popping the sentinels
      wait_until { pool.size == initial - 2 }

      expect(pool.size).to eq(initial - 2)
    end

    context "when downscale sentinels are still in flight (busy workers)" do
      # Swallow the sentinels so no worker ever picks them up - simulates a pool where all
      # workers are busy with long-running jobs and deregistration has not happened yet
      before { allow(jobs_queue).to receive(:<<) }

      it "does not enqueue duplicate sentinels for repeated same-target requests" do
        initial = pool.size

        pool.scale(1)
        pool.scale(1)

        expect(jobs_queue).to have_received(:<<).with(nil).exactly(initial - 1).times
      end

      it "emits only one scaling.down event for repeated same-target requests" do
        pool.scale(1)
        pool.scale(1)

        expect(down_events.size).to eq(1)
      end

      it "scales up against the committed size, not the live fibers count" do
        initial = pool.size

        pool.scale(1)
        # Committed size is 1 now, so reaching 3 requires only 2 new workers even though all
        # initial fibers are still alive
        pool.scale(3)

        expect(pool.size).to eq(initial + 2)
      end
    end
  end

  describe "#deregister" do
    it "removes the worker from the pool" do
      worker = pool.alive.first
      initial = pool.size
      pool.deregister(worker)
      expect(pool.size).to eq(initial - 1)
    end

    it "does not let shutdown deregistrations corrupt pending shrink accounting" do
      pool.deregister(pool.alive.first)

      allow(jobs_queue).to receive(:<<)
      pool.scale(pool.size - 1)

      expect(jobs_queue).to have_received(:<<).with(nil).once
    end
  end

  describe "#join" do
    it "waits for all workers and carriers to finish" do
      jobs_queue.close
      expect { pool.join }.not_to raise_error
      expect(pool.stopped?).to be(true)
    end
  end

  describe "#terminate" do
    it "kills the carrier threads" do
      pool.terminate
      pool.join
      # Terminated carriers can never finish their worker fibers, but their threads are gone
      expect(Thread.list.map(&:name)).not_to include("karafka.carrier#0")
    end
  end

  describe "fiber-based processing" do
    let(:events) { Queue.new }
    let(:collected) do
      log = []
      log << events.pop until events.empty?
      log
    end

    let(:carrier_threads) { 1 }

    before do
      # Must happen before the subject (pool) is referenced, as the pool reads this setting
      # when starting its carriers
      Karafka::App.config.workers.carrier_threads = carrier_threads

      jobs_queue.pool = pool
      jobs_queue.register("group1")
    end

    after { Karafka::App.config.workers.carrier_threads = 1 }

    context "with a single carrier thread" do
      it "multiplexes IO-bound jobs concurrently on one thread" do
        pool

        3.times { |i| jobs_queue << job_class.new("group1", i, events, 0.2) }

        wait_until { events.size == 6 }

        starts = collected.select { |e| e[0] == :start }
        stops = collected.select { |e| e[0] == :stop }

        # All jobs ran on the same carrier thread...
        expect((starts + stops).map { |e| e[2] }.uniq).to eq(["karafka.carrier#0"])
        # ...yet all of them were in flight at the same time (fibers multiplexing)
        expect(starts.map(&:last).max).to be < stops.map(&:last).min
      end
    end

    context "when fibers on one carrier contend on a Mutex" do
      it "serializes the critical sections without deadlocking the carrier" do
        pool

        mutex = Mutex.new
        order = Queue.new

        contending_job_class = Class.new(job_class)
        contending_job_class.define_method(:call) do
          mutex.synchronize do
            order << [:start, id]
            # Scheduler-aware sleep inside the lock: other fibers must wait on the mutex
            # without freezing the carrier thread
            sleep(0.1)
            order << [:stop, id]
          end
        end

        3.times { |i| jobs_queue << contending_job_class.new("group1", i, events, 0) }

        wait_until { order.size == 6 }

        log = []
        log << order.pop until order.empty?

        # Critical sections must not interleave: every start is immediately followed by the
        # stop of the same job
        log.each_slice(2) do |(start, stop)|
          expect(start[0]).to eq(:start)
          expect(stop[0]).to eq(:stop)
          expect(start[1]).to eq(stop[1])
        end
      end
    end

    context "when jobs use Thread.current[] storage" do
      it "keeps the storage per fiber so concurrent jobs do not see each other's state" do
        pool

        states = Queue.new

        stateful_job_class = Class.new(job_class)
        stateful_job_class.define_method(:call) do
          Thread.current[:fiber_state] = id
          # Interleave with the other jobs on the same carrier before reading back
          sleep(0.2)
          states << [id, Thread.current[:fiber_state]]
        end

        3.times { |i| jobs_queue << stateful_job_class.new("group1", i, events, 0) }

        wait_until { states.size == 3 }

        until states.empty?
          id, state = states.pop

          expect(state).to eq(id)
        end
      end
    end

    context "when an error escapes the worker processing loop" do
      it "re-raises on the main thread (threads abort_on_exception parity) and deregisters" do
        pool

        # Emulates a re-raising error instrumentation subscriber, the same way end users can
        # break out of the worker recovery flow
        Karafka.monitor.subscribe("error.occurred") do |event|
          raise event[:error] if event[:type] == "worker.process.error"
        end

        failing_job = job_class.new("group1", 0, events, 0)
        allow(failing_job).to receive(:call).and_raise(IOError, "fiber boom")

        initial = pool.size
        caught = nil

        begin
          jobs_queue << failing_job
          sleep(5)
        rescue IOError => e
          caught = e
        end

        expect(caught&.message).to eq("fiber boom")

        # The crashed worker deregisters so shutdown accounting stays truthful
        wait_until { pool.size == initial - 1 }
      end
    end

    context "with multiple carrier threads" do
      let(:carrier_threads) { 2 }

      it "distributes worker fibers across all carriers" do
        pool

        # Let all worker fibers spawn and park on the jobs queue first. Job distribution is
        # pull-based (longest-waiting fiber first), so if one carrier boots faster, its fibers
        # could otherwise consume everything before the other carrier's fibers start waiting
        sleep(0.3)

        # With all fibers parked, each of the `concurrency` long jobs occupies a distinct fiber
        concurrency.times { |i| jobs_queue << job_class.new("group1", i, events, 0.5) }

        wait_until { events.size == concurrency * 2 }

        names = collected.map { |e| e[2] }.uniq.sort

        expect(names).to eq(%w[karafka.carrier#0 karafka.carrier#1])
      end
    end
  end
end
