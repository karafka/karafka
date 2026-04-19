# frozen_string_literal: true

module Karafka
  module Processing
    # Dynamic thread pool that manages worker threads.
    # Supports scaling at runtime via {#scale}.
    #
    # All public methods that read or mutate `@workers` are synchronized via `@mutex`.
    # `@size` is always updated under `@mutex` but can be read without locking for performance
    # (integer assignment is atomic in MRI).
    class WorkersPool
      include Helpers::ConfigImporter.new(
        concurrency: %i[concurrency],
        worker_thread_priority: %i[worker_thread_priority],
        monitor: %i[monitor]
      )

      # @return [Integer] current number of workers registered in the pool.
      #   Reflects the actual thread count, not a target. After a downscale request this value
      #   converges towards the target as workers pick up nil sentinels and deregister.
      #   Updated atomically under mutex, safe to read without locking.
      attr_reader :size

      # Jobs queue reference, set by the Runner after both pool and queue are created.
      # Must be assigned before calling {#scale}.
      attr_writer :jobs_queue

      # Initializes an empty pool with zero workers.
      # Workers are not started until {#scale} is called, allowing the pool to be created early
      # (e.g. in Server.run) before the jobs queue exists.
      #
      # @return [WorkersPool]
      def initialize
        @jobs_queue = nil
        @workers = []
        @size = 0
        @mutex = Mutex.new
        # Monotonically increasing index for naming worker threads. Indices are never reused
        # after a worker exits, so thread names remain unique across the lifetime of the process
        # and make it easy to correlate log entries with specific worker generations.
        @next_index = 0
      end

      # Scale pool towards `target` workers (minimum 1).
      #
      # **Scaling up** is synchronous -- new worker threads are spawned and registered before this
      # method returns. {#size} reflects the new count immediately.
      #
      # **Scaling down** is asynchronous -- nil sentinels are enqueued and workers exit when they
      # pick one up. {#size} decreases gradually as workers deregister themselves. Callers that
      # need to know when downsizing is complete should poll {#size} or listen for the
      # `worker.scaling.down` instrumentation event (whose `:to` payload reports the *target*,
      # not the current count).
      #
      # The entire read-decide-act cycle is synchronized to prevent stale reads.
      # Instrumentation runs outside the mutex to avoid holding the lock during user callbacks.
      #
      # @param target [Integer] desired number of workers
      def scale(target)
        raise(Karafka::Errors::BaseError, "jobs_queue must be set before scaling") unless @jobs_queue

        target = [target, 1].max
        event = nil

        @mutex.synchronize do
          current = @workers.size
          delta = target - current

          if delta.positive?
            event = grow(delta)
          elsif delta.negative?
            event = shrink(delta.abs)
          end
        end

        return unless event

        monitor.instrument(*event)
      end

      # @return [Boolean] true if all workers have stopped
      def stopped?
        snapshot.none?(&:alive?)
      end

      # @return [Array<Worker>] workers that are still alive
      def alive
        snapshot.select(&:alive?)
      end

      # Forcefully terminate all worker threads.
      def terminate
        snapshot.each(&:terminate)
      end

      # Wait for all current workers to finish.
      def join
        snapshot.each(&:join)
      end

      # Called by a worker when it exits (queue closed or pool downscaling).
      # Thread-safe -- worker threads call this from their own thread.
      #
      # @param worker [Worker] worker to remove from the pool
      def deregister(worker)
        @mutex.synchronize do
          @workers.delete(worker)
          @size = @workers.size
        end
      end

      private

      # @return [Array<Worker>] snapshot of workers taken under mutex
      def snapshot
        @mutex.synchronize { @workers.dup }
      end

      # Add `count` workers and start their threads immediately.
      # Must be called under `@mutex` (from {#scale}) or during construction (no contention).
      #
      # @param count [Integer] number of workers to add
      # @return [Array] instrumentation event args to be emitted outside the mutex
      def grow(count)
        from = @workers.size

        count.times do
          worker = Worker.new(@jobs_queue, self)
          @workers << worker
          worker.async_call("karafka.worker##{@next_index}", worker_thread_priority)
          @next_index += 1
        end

        @size = @workers.size

        ["worker.scaling.up", { workers_pool: self, from: from, to: @size }]
      end

      # Push nil into the queue to signal workers to exit.
      # Whichever workers pick them up will deregister and stop.
      # Must be called under `@mutex` (from {#scale}).
      #
      # @param count [Integer] number of workers to remove
      # @return [Array, nil] instrumentation event args or nil if no-op
      # @note Never shrinks below 1 worker.
      def shrink(count)
        effective = [count, @workers.size - 1].min
        return if effective <= 0

        from = @workers.size
        effective.times { @jobs_queue << nil }
        to = from - effective

        ["worker.scaling.down", { workers_pool: self, from: from, to: to }]
      end
    end
  end
end
