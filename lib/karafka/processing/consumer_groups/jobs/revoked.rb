# frozen_string_literal: true

module Karafka
  module Processing
    # Consumer-group-specific processing components (driven by rebalance callbacks and partition
    # ticks). Parallel `ShareGroups` will live next to this namespace once KIP-932 lands.
    module ConsumerGroups
      # Consumer-group-specific job types
      module Jobs
        # Job that runs the revoked operation when we lose a partition on a consumer that lost it.
        class Revoked < Processing::Jobs::Base
          self.action = :revoked

          # @param executor [Karafka::Processing::ConsumerGroups::Executor] executor that is supposed to run the job
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
end
