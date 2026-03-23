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
      # Uses mutex + port pattern for efficient work distribution
      #
      # Architecture:
      # - Workers signal availability via @ready_port
      # - Each worker has its own port for receiving work
      # - Each caller creates a result_port for receiving results
      # - Mutex only held during dispatch, not during processing
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
          @dispatch_mutex = nil
          @ready_queue = []
          @distributor = nil
          @min_payloads = 50
        end

        # Starts the pool with the specified number of workers
        # @param concurrency [Integer] number of Ractor workers to create
        # @param distributor [Distributor] strategy for splitting payloads across workers
        # @param min_payloads [Integer] minimum batch size to dispatch to Ractors
        def start(concurrency, distributor: Distributor.new, min_payloads: 50)
          @mutex.synchronize do
            return if @started

            @size = concurrency
            @distributor = distributor
            @min_payloads = min_payloads
            @ready_port = Ractor::Port.new
            @dispatch_mutex = Mutex.new
            create_workers
            wait_for_workers_ready
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
          @dispatch_mutex = nil
          @ready_queue = []
          @distributor = nil
          @min_payloads = 50
        end

        # Dispatches messages for async deserialization, returns Future for later retrieval
        # Non-blocking: dispatches work and returns immediately
        # Used for early dispatch in listener thread before job is scheduled
        # @param messages [Karafka::Messages::Messages] batch of messages
        # @param deserializer [Object] deserializer that responds to #call
        #   Must be Ractor-safe (frozen or shareable) when parallel deserialization is enabled
        # @return [Future, Immediate] future for retrieving results, or Immediate if skipped
        def dispatch_async(messages, deserializer)
          return Immediate.instance if messages.empty?
          return Immediate.instance unless @started
          return Immediate.instance if messages.size < @min_payloads

          # Dispatch to Ractor pool - distribute across workers
          payloads = messages.map(&:raw_payload)
          batches = @distributor.call(payloads, @size, min_payloads: @min_payloads)
          result_port = Ractor::Port.new

          batches.each_with_index do |batch, idx|
            dispatch_batch(batch, idx, result_port, deserializer)
          end

          # Return future for later retrieval
          Future.new(result_port, batches.size)
        end

        private

        # Dispatches a batch of payloads to an available worker
        # Uses move: true for zero-copy transfer of payload strings to Ractor.
        # This avoids expensive deep-copy of potentially large payloads (up to MBs).
        # After move, the batch array is invalidated in the sending thread.
        # @param batch [Array<String>] raw payloads
        # @param batch_index [Integer] index for result ordering
        # @param result_port [Ractor::Port] port for receiving results
        # @param deserializer [Object] Ractor-safe deserializer
        def dispatch_batch(batch, batch_index, result_port, deserializer)
          @dispatch_mutex.synchronize do
            ready_msg = @ready_queue.shift || @ready_port.receive
            ready_msg[:port].send({
              batch_index: batch_index,
              data: batch,
              result_port: result_port,
              deserializer: deserializer
            }.freeze, move: true)
          end
        end

        # Waits for all workers to signal readiness
        def wait_for_workers_ready
          @size.times { @ready_queue << @ready_port.receive }
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
              # Signal ready
              ready_p.send(ready_signal)

              # Wait for work
              msg = my_port.receive
              break if msg == :stop

              # Deserialize batch using the provided deserializer
              deserializer = msg[:deserializer]

              results = msg[:data].map do |payload|
                deserializer.call(proxy_class.new(raw_payload: payload))
              rescue StandardError
                err_marker
              end

              # Send results to caller's port
              # Frozen for zero-copy transfer back to caller
              msg[:result_port].send({
                batch_index: msg[:batch_index],
                results: results.freeze
              }.freeze)
            end
          end
        end
      end
    end
  end
end
