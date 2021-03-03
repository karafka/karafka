# frozen_string_literal: true

module Karafka
  module Processing
    module Jobs
      # Job that runs on each active consumer upon process shutdown (one job per consumer).
      class Shutdown < Base
        # @param executor [Karafka::Processing::Executor] executor that is suppose to run a given
        #   job on an active consumer
        # @return [Shutdown]
        def initialize(executor)
          @executor = executor
          super()
        end

        # Runs the shutdown job via an executor.
        def call
          executor.shutdown
        end
      end
    end
  end
end
