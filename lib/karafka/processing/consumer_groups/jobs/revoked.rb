# frozen_string_literal: true

module Karafka
  module Processing
    module Jobs
      # Job that runs the revoked operation when we loose a partition on a consumer that lost it.
      class Revoked < Base
        self.action = :revoked

        # @param executor [Karafka::Processing::Executor] executor that is suppose to run the job
        # @return [Revoked]
        def initialize(executor)
          @executor = executor
          super()
        end

        # Runs code prior to scheduling this revoked job
        def before_schedule
          executor.before_schedule_revoked
        end

        # Runs the revoking job via an executor.
        def call
          executor.revoked
        end
      end
    end
  end
end
