# frozen_string_literal: true

module Karafka
  module Processing
    # Consumer-group-specific processing components (driven by rebalance callbacks and partition
    # ticks). Parallel `ShareGroups` will live next to this namespace once KIP-932 lands.
    module ConsumerGroups
      # Consumer-group-specific job types
      module Jobs
        # Job that runs the eofed operation when we receive eof without messages alongside.
        class Eofed < Processing::Jobs::Base
          self.action = :eofed

          # @param executor [Karafka::Processing::Executor] executor that is suppose to run the job
          # @return [Eofed]
          def initialize(executor)
            @executor = executor
            super()
          end

          # Runs code prior to scheduling this eofed job
          def before_schedule
            executor.before_schedule_eofed
          end

          # Runs the eofed job via an executor.
          def call
            executor.eofed
          end
        end
      end
    end
  end
end
