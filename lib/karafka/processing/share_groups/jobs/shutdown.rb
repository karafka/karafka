# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      module Jobs
        # Job that runs on each active share consumer upon process shutdown (one job per consumer).
        class Shutdown < ::Karafka::Processing::Jobs::Base
          self.action = :shutdown

          # @param executor [Karafka::Processing::ShareGroups::Executor] executor that is supposed
          #   to run a given job on an active consumer
          # @return [Shutdown]
          def initialize(executor)
            @executor = executor
            super()
          end

          # Runs code prior to scheduling this shutdown job
          def before_schedule
            executor.before_schedule_shutdown
          end

          # Runs the shutdown job via an executor.
          def call
            executor.shutdown
          end
        end
      end
    end
  end
end
