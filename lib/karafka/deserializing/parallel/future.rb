# frozen_string_literal: true

module Karafka
  module Deserializing
    module Parallel
      # Represents a pending async deserialization dispatched to Ractor pool.
      # Created in listener thread during before_schedule_consume, retrieved in worker thread
      # during handle_before_consume. This allows Ractors to work while jobs wait in queue.
      #
      # Responsible only for collecting results from Ractors.
      # Payload injection is handled separately by Injector.
      class Future
        # @param result_port [Ractor::Port] port for receiving results from Ractor workers
        # @param batch_count [Integer] number of batches dispatched to workers
        def initialize(result_port, batch_count)
          @result_port = result_port
          @batch_count = batch_count
          @results = Array.new(batch_count)
          @received_count = 0
          @retrieved = false
        end

        # Retrieves results from Ractor pool, blocking if necessary until all batches complete.
        # Safe to call multiple times - returns cached results if already retrieved.
        #
        # @return [Array] flattened array of deserialized results in original message order
        def retrieve
          return @flattened_results if @retrieved

          # Collect all batch results from Ractor workers
          while @received_count < @batch_count
            msg = @result_port.receive
            @results[msg[:batch_index]] = msg[:results]
            @received_count += 1
          end

          @retrieved = true
          @flattened_results = @results.flatten
        end
      end
    end
  end
end
