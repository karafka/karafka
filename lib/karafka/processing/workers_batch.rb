# frozen_string_literal: true

module Karafka
  module Processing
    # Abstraction layer around workers batch.
    class WorkersBatch
      include Enumerable
      include Helpers::ConfigImporter.new(
        concurrency: %i[concurrency]
      )

      # @param jobs_queue [JobsQueue]
      # @return [WorkersBatch]
      def initialize(jobs_queue)
        @batch = Array.new(concurrency) { Processing::Worker.new(jobs_queue) }
      end

      # Iterates over available workers and yields each worker
      # @param block [Proc] block we want to run
      def each(&block)
        @batch.each(&block)
      end

      # @return [Integer] number of workers in the batch
      def size
        @batch.size
      end
    end
  end
end
