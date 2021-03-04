# frozen_string_literal: true

module Karafka
  module Processing
    # Abstraction layer around workers batch.
    class WorkersBatch
      # @param jobs_queue [JobsQueue]
      # @return [WorkersBatch]
      def initialize(jobs_queue)
        @batch = Array.new(App.config.concurrency) { Processing::Worker.new(jobs_queue) }
      end
    end
  end
end
