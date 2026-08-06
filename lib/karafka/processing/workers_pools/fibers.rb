# frozen_string_literal: true

module Karafka
  module Processing
    # Namespace for alternative workers pool implementations selected via the
    # `workers.backend` setting. The default threads-based pool is `Processing::WorkersPool`.
    module WorkersPools
      # Fibers-based workers pool.
      #
      # Runs workers as fibers hosted on a configurable number of carrier threads, each running
      # an `Async` reactor. Aimed at IO-bound workloads: while one worker fiber waits on
      # scheduler-aware IO (sockets, `sleep`, `Queue`, `Mutex`), other fibers on the same
      # carrier keep processing, so high `workers.concurrency` values do not cost a thread each.
      #
      # Distribution model is identical to the threads pool: all worker fibers (across all
      # carriers) block on the same jobs queue and whichever has waited longest picks up the
      # next job. Jobs are never pinned to carriers.
      #
      # The pool contract is inherited from {Processing::WorkersPool}: `#size` reports worker
      # fibers (execution slots, not carrier threads) so the jobs queue busy/enqueued statistics
      # remain truthful, and downscaling reuses the `nil` sentinel protocol - whichever worker
      # fiber pops a sentinel deregisters and finishes.
      #
      # @note C-level calls that do not yield to the fiber scheduler (librdkafka operations like
      #   sync offset commits, some DB drivers) block their whole carrier thread, freezing all
      #   fibers hosted on it (other carriers are unaffected as such calls release the GVL).
      #   Workloads mixing such calls with latency-sensitive jobs should increase
      #   `workers.carrier_threads`.
      class Fibers < WorkersPool
        include Helpers::ConfigImporter.new(
          carrier_threads_count: %i[workers carrier_threads]
        )

        # Worker running as a fiber on a carrier thread. Reuses the whole processing loop from
        # {Processing::Worker} and only replaces the thread-based execution vehicle awareness.
        class Worker < Processing::Worker
          # @return [String] name assigned to this worker (kept for logging parity with the
          #   thread-based workers where it names the worker thread)
          attr_reader :name

          # @param jobs_queue [JobsQueue]
          # @param pool [Fibers] pool this worker belongs to
          # @param name [String] worker name
          def initialize(jobs_queue, pool, name)
            super(jobs_queue, pool)
            @name = name
            @finished = false
          end

          # Runs the worker processing loop. Executed inside a fiber on a carrier thread.
          def fiber_call
            crashed = true
            call
            crashed = false
          ensure
            @finished = true

            # A worker that exits cleanly (queue closed or downscale sentinel) deregisters
            # inside the processing loop. A crashed one never reaches that path, so we
            # deregister here - otherwise the pool would forever wait for it on shutdown and
            # never close the carriers
            @pool.deregister(self) if crashed
          end

          # @return [Boolean] true until the worker fiber finished its processing loop. A worker
          #   scheduled on a carrier but not yet started reports alive, mirroring thread-based
          #   workers that are alive right after spawn.
          def alive?
            !@finished
          end
        end

        # Thread hosting an `Async` reactor on which worker fibers run.
        #
        # Workers are handed over via a scheduler-aware control queue: while the control fiber
        # waits for new workers to host, already spawned worker fibers keep running. Closing the
        # control queue tells the carrier no more workers will arrive; its thread finishes once
        # all hosted worker fibers finish.
        class Carrier
          # @param name [String] carrier thread name
          # @param priority [Integer] carrier thread priority
          def initialize(name, priority)
            @name = name
            @priority = priority
            @commands = Queue.new
            @thread = nil
          end

          # Starts the carrier thread with its reactor.
          def start
            @thread = Thread.new do
              Thread.current.name = @name
              Thread.current.priority = @priority
              Thread.current.abort_on_exception = true

              Sync do |task|
                workers = []

                # Scheduler-aware blocking pop: worker fibers run while we wait here
                while (worker = @commands.pop)
                  workers << host(task, worker)
                end

                # Closed commands queue means shutdown was requested. We wait for all the
                # worker fibers to finish their loops (they exit when the jobs queue closes or
                # when they pick up a downscale sentinel) before letting the thread end.
                workers.each(&:wait)
              end
            end
          end

          # Schedules a worker to run as a fiber on this carrier.
          #
          # @param worker [Fibers::Worker] worker to host
          def schedule(worker)
            @commands << worker
          end

          # Signals the carrier that no more workers will arrive. Idempotent.
          def close
            @commands.close
          end

          # @return [Boolean] true if this carrier was closed and cannot host new workers
          def closed?
            @commands.closed?
          end

          # @return [Boolean] true if the carrier thread is running
          def alive?
            @thread ? @thread.alive? : false
          end

          # Waits for the carrier thread to finish.
          def join
            @thread&.join
          end

          # Forcefully terminates the carrier thread and with it all its worker fibers.
          def terminate
            @thread&.terminate
          end

          private

          # Spawns the worker fiber. Extracted to a method so each fiber closes over its own
          # `worker` binding - inlining this in the `while` loop would make all fibers share the
          # loop variable and race on the same worker instance.
          #
          # @param task [Async::Task] carrier root task
          # @param worker [Fibers::Worker] worker to host
          # @return [Async::Task] task running the worker fiber
          def host(task, worker)
            task.async do
              worker.fiber_call
            rescue Async::Stop
              # Reactor-driven stop of the fiber is a controlled operation, not a worker crash
            rescue Exception => e # rubocop:disable Lint/RescueException
              # Parity with the thread workers where `abort_on_exception = true` causes any
              # error escaping the worker loop to crash the process loudly. Without this, the
              # error would stay parked inside the async task until the carrier waits on it
              # during shutdown, silently killing this worker fiber in the meantime
              Thread.main.raise(e)
            end
          end
        end

        # @return [Fibers]
        def initialize
          super
          @carriers = []
          # Monotonically increasing index for naming carrier threads, so carriers started
          # after a full stop-start cycle get unique names
          @next_carrier_index = 0
        end

        # Waits for all carrier threads (and with them all worker fibers) to finish.
        def join
          carriers_snapshot.each(&:join)
        end

        # Forcefully terminates all carrier threads, killing all hosted worker fibers.
        def terminate
          carriers_snapshot.each(&:terminate)
        end

        # Called by a worker fiber when it exits (queue closed or pool downscaling).
        #
        # @param worker [Fibers::Worker] worker to remove from the pool
        def deregister(worker)
          super

          # Once the last worker exits, the pool is shutting down (scaling never goes below one
          # worker), so we close the carriers to let their reactors and threads finish
          @mutex.synchronize do
            @carriers.each(&:close) if @workers.empty?
          end
        end

        private

        # @return [Array<Carrier>] snapshot of carriers taken under mutex
        def carriers_snapshot
          @mutex.synchronize { @carriers.dup }
        end

        # Adds `count` workers and schedules them on carriers round-robin.
        # Carriers are started lazily on first growth so building the pool (which happens even
        # in processes that never run workers) does not spawn threads.
        # Must be called under `@mutex` (from {WorkersPool#scale}).
        #
        # @param count [Integer] number of workers to add
        # @return [Array] instrumentation event args to be emitted outside the mutex
        def grow(count)
          # Carriers that ended or were closed for shutdown cannot host new workers. Their
          # threads finish on their own; scaling after a full stop starts fresh ones.
          @carriers.reject! { |carrier| carrier.closed? || !carrier.alive? }

          start_carriers if @carriers.empty?

          from = @workers.size

          count.times do
            worker = Worker.new(@jobs_queue, self, "karafka.worker##{@next_index}")
            @workers << worker
            @carriers[@next_index % @carriers.size].schedule(worker)
            @next_index += 1
          end

          @size = @workers.size

          ["worker.scaling.up", { workers_pool: self, from: from, to: @size }]
        end

        # Starts the configured number of carrier threads.
        # Must be called under `@mutex`.
        def start_carriers
          carrier_threads_count.times do
            carrier = Carrier.new("karafka.carrier##{@next_carrier_index}", worker_thread_priority)
            @carriers << carrier
            carrier.start
            @next_carrier_index += 1
          end
        end
      end
    end
  end
end
