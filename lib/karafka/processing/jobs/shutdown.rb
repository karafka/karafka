# frozen_string_literal: true

module Karafka
  module Processing
    module Jobs
      # Job that runs on active executors upon shutdown
      class Shutdown < Base
        # @param executor [Karafka::Processing::Executor] executor that is suppose to run a given
        #   job
        # @return [Shutdown]
        def initialize(executor)
          @executor = executor
        end

        # Runs the shutdown job via an executor
        def call
          executor.shutdown
        end
      end
    end
  end
end
