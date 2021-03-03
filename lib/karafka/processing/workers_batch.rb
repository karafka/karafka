# frozen_string_literal: true

module Karafka
  module Processing
    class WorkersBatch
      def initialize(jobs_queue)
        @batch = App.config.processing.concurrency.times.map { Processing::Worker.new(jobs_queue) }
      end
    end
  end
end
