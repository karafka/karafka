# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      module Jobs
        # Job used to run housekeeping on a share consumer without any user lifecycle event (no
        # messages passed to the end user). Scheduled when a poll returns no records.
        class Idle < ::Karafka::Processing::Jobs::Base
          self.action = :idle

          # @param executor [Karafka::Processing::ShareGroups::Executor] executor that is supposed
          #   to run a given job on an active consumer
          # @return [Idle]
          def initialize(executor)
            @executor = executor
            super()
          end

          # Runs code prior to scheduling this idle job
          def before_schedule
            executor.before_schedule_idle
          end

          # Runs the idle work via the executor
          def call
            executor.idle
          end
        end
      end
    end
  end
end
