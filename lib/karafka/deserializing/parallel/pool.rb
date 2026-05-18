# frozen_string_literal: true

module Karafka
  module Deserializing
    # Namespace for parallel deserialization using Ractors
    # Requires Ruby 4.0+ for stable Ractor APIs
    module Parallel
      # Marker for failed deserialization - used instead of actual error to keep it simple
      # Messages marked with this will be retried via lazy deserialization during consumption
      # Frozen objects are automatically Ractor-shareable in Ruby 4.0+
      DESERIALIZATION_ERROR = Object.new.freeze

      # Manages a pool of Ractor workers for parallel message deserialization
      #
      # Architecture:
      # - Listener threads push work to a thread-safe queue (non-blocking)
      # - A background coordinator thread feeds Ractor workers from the queue
      # - Workers signal availability via @ready_port after completing each batch
      # - Coordinator loop: wait for work → wait for ready worker → dispatch
      #
      # This ensures workers are always busy when there's queued work, even across
      # multiple subscription groups with different batch sizes.
      class Pool
        include Singleton

        # @return [Integer] number of workers in the pool
        attr_reader :size

        def initialize
          @workers = []
          @size = 0
          @mutex = Mutex.new
          @started = false
          @ready_port = nil
          @work_queue = nil
          @coordinator = nil
          @min_payloads = 50
        end

        # Starts the pool with the specified number of workers and the coordinator thread
        # @param concurrency [Integer] number of Ractor workers to create
        # @param min_payloads [Integer] minimum batch size to dispatch to Ractors
        def start(concurrency, min_payloads:)
          @mutex.synchronize do
            return if @started

            @size = concurrency
            @min_payloads = min_payloads
            @ready_port = Ractor::Port.new
            @work_queue = Thread::Queue.new
            create_workers
            start_coordinator
            @started = true
          end
        end

        # @return [Boolean] is the pool started and ready
        def started?
          @started
        end

        # Resets the pool state
        # This is used in the test suite
        def reset!
          @workers = []
          @size = 0
          @started = false
          @ready_port = nil
          @work_queue = nil
          @coordinator = nil
          @min_payloads = 50
        end

        # Dispatches messages for parallel deserialization
        # Non-blocking: pushes work to queue and returns Future immediately
        # @param messages [Karafka::Messages::Messages] batch of messages
        # @param deserializer [Object] deserializer that responds to #call
        #   Must be Ractor-safe (frozen or shareable) when parallel deserialization is enabled
        # @param distributor [Object] strategy for splitting payloads across workers
        # @return [Future, Immediate] future for retrieving results, or Immediate if skipped
        def dispatch_async(messages, deserializer, distributor)
          return Immediate.instance if messages.empty?
          return Immediate.instance unless @started
          return Immediate.instance if messages.size < @min_payloads

          payloads = messages.map(&:raw_payload)
          batches = distributor.call(payloads, @size, min_payloads: @min_payloads)
          result_port = Ractor::Port.new

          offset = 0

          batches.each_with_index do |batch, idx|
            @work_queue << {
              batch_index: idx,
              offset: offset,
              data: batch,
              result_port: result_port,
              deserializer: deserializer
            }

            offset += batch.size
          end

          Future.new(result_port, batches.size, payloads.size)
        end

        private

        # Starts the background coordinator thread
        # Waits for work in the queue, then waits for a ready worker, then dispatches
        def start_coordinator
          @coordinator = Thread.new do
            loop do
              # 1. Wait for work (blocks until a listener pushes something)
              work = @work_queue.pop
              break if work == :stop

              # 2. Wait for a ready worker
              ready = @ready_port.receive

              # 3. Dispatch work to the ready worker
              ready[:port].send(work.freeze)
            end
          end

          @coordinator.name = "karafka.parallel_deser.coordinator"
          @coordinator.abort_on_exception = true
        end

        # Creates persistent Ractor workers
        def create_workers
          ready_port = @ready_port

          @size.times do |worker_id|
            @workers << create_worker(worker_id, ready_port)
          end
        end

        # Creates a single Ractor worker
        # Worker creates its own port, signals readiness, processes work, sends results
        # @param worker_id [Integer]
        # @param ready_port [Ractor::Port] port to signal availability
        # @return [Ractor] the created worker
        def create_worker(worker_id, ready_port)
          error_marker = DESERIALIZATION_ERROR

          Ractor.new(
            worker_id,
            ready_port,
            error_marker,
            MessageProxy,
            name: "pd_worker_#{worker_id}"
          ) do |wid, ready_p, err_marker, proxy_class|
            my_port = Ractor::Port.new

            ready_signal = { worker_id: wid, port: my_port }.freeze

            loop do
              # Signal ready to coordinator
              ready_p.send(ready_signal)

              # Wait for work from coordinator
              msg = my_port.receive
              break if msg == :stop

              # Deserialize batch using the provided deserializer
              deserializer = msg[:deserializer]

              results = msg[:data].map do |payload|
                deserializer.call(proxy_class.new(raw_payload: payload))
              rescue
                err_marker
              end

              # Send results to caller's port
              msg[:result_port].send({
                offset: msg[:offset],
                results: results.freeze
              }.freeze)
            end
          end
        end
      end
    end
  end
end
