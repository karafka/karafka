# frozen_string_literal: true

module Karafka
  module Processing
    module Jobs
      # Job that runs the eofed operation when we receive eof without messages alongside.
      class Eofed < Base
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
