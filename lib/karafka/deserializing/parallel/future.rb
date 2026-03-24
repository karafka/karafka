# frozen_string_literal: true

module Karafka
  module Deserializing
    module Parallel
      # Represents a pending parallel deserialization dispatched to the Ractor pool.
      # Created by Pool#dispatch_async, retrieved in worker thread during handle_before_consume.
      #
      # Responsible only for collecting results from Ractors.
      # Payload injection is handled separately by Injector.
      class Future
        # @param result_port [Ractor::Port] port for receiving results from Ractor workers
        # @param batch_count [Integer] number of batches dispatched to workers
        # @param chunk_size [Integer] size of each chunk for offset calculation
        # @param total [Integer] total number of messages dispatched
        def initialize(result_port, batch_count, chunk_size, total)
          @result_port = result_port
          @batch_count = batch_count
          @chunk_size = chunk_size
          @total = total
          @retrieved = false
        end

        # Retrieves results from Ractor pool, blocking if necessary until all batches complete.
        # Safe to call multiple times - returns cached results if already retrieved.
        #
        # @return [Array] array of deserialized results in original message order
        def retrieve
          return @results if @retrieved

          @results = Array.new(@total)

          # Collect all batch results from Ractor workers
          @batch_count.times do
            msg = @result_port.receive
            offset = msg[:batch_index] * @chunk_size
            msg[:results].each_with_index { |r, j| @results[offset + j] = r }
          end

          @retrieved = true
          @results
        end
      end
    end
  end
end
