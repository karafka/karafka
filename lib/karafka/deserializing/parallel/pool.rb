# frozen_string_literal: true

module Karafka
  module Deserializing
    # Namespace for parallel deserialization using Ractors
    # Requires Ruby 4.0+ for stable Ractor APIs
    module Parallel
      # Marker for failed deserialization - used instead of actual error to keep it simple
      # Messages marked with this will be retried via lazy deserialization during consumption
      # Made Ractor-shareable on Ruby 3.0+ for passing between Ractors
      DESERIALIZATION_ERROR = begin
        obj = Object.new
        defined?(Ractor) ? Ractor.make_shareable(obj) : obj.freeze
      end

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
          @config = nil
        end

        # Starts the pool with the specified number of workers
        # @param concurrency [Integer] number of Ractor workers to create
        def start(concurrency)
          @mutex.synchronize do
            return if @started

            @size = concurrency
            @config = Karafka::App.config.deserializing.parallel
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
          @config = nil
        end

        # Dispatches messages for async deserialization, returns Future for later retrieval
        # Non-blocking: dispatches work and returns immediately
        # Used for early dispatch in listener thread before job is scheduled
        # @param messages [Karafka::Messages::Messages] batch of messages
        # @param deserializer [Object] Ractor-shareable deserializer that responds to #call
        # @return [Future, Immediate] future for retrieving results, or Immediate if skipped
        # @note Deserializer must be Ractor-shareable (frozen or made shareable)
        def dispatch_async(messages, deserializer)
          return Immediate.instance if messages.empty?
          return Immediate.instance unless @started

          # Check thresholds - if not met, return Immediate (lazy deserialization will handle it)
          return Immediate.instance if messages.size < @config.batch_threshold

          total_size = messages.sum { |m| m.raw_payload&.bytesize || 0 }
          return Immediate.instance if total_size < @config.total_payload_threshold

          # Dispatch to Ractor pool
          payloads = messages.map(&:raw_payload)
          batches = payloads.each_slice(@config.batch_size).to_a
          result_port = Ractor::Port.new

          batches.each_with_index do |batch, idx|
            dispatch_batch(batch, idx, result_port, deserializer)
          end

          # Return future for later retrieval
          Future.new(result_port, batches.size)
        end

        private

        # Dispatches a batch of payloads to an available worker
        # @param batch [Array<String>] raw payloads
        # @param batch_index [Integer] index for result ordering
        # @param result_port [Ractor::Port] port for receiving results
        # @param deserializer [Object] Ractor-shareable deserializer
        def dispatch_batch(batch, batch_index, result_port, deserializer)
          @dispatch_mutex.synchronize do
            ready_msg = @ready_queue.shift || @ready_port.receive
            ready_msg[:port].send({
              batch_index: batch_index,
              data: batch,
              result_port: result_port,
              deserializer: deserializer
            })
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
            name: "pd_worker_#{worker_id}"
          ) do |wid, ready_p, err_marker|
            my_port = Ractor::Port.new

            loop do
              # Signal ready
              ready_p.send({ worker_id: wid, port: my_port })

              # Wait for work
              msg = my_port.receive
              break if msg == :stop

              # Deserialize batch using the shareable deserializer directly
              deserializer = msg[:deserializer]

              results = msg[:data].map do |payload|
                message_proxy = Struct.new(:raw_payload).new(payload)
                deserializer.call(message_proxy)
              rescue StandardError
                err_marker
              end

              # Send results to caller's port
              msg[:result_port].send({
                batch_index: msg[:batch_index],
                results: results
              })
            end
          end
        end
      end
    end
  end
end
