# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Jobs
        # Job that represents a "ticking" work. Work that we run periodically for the Periodics
        # enabled topics.
        class Periodic < ::Karafka::Processing::Jobs::Base
          self.action = :tick

          # @param executor [Karafka::Pro::Processing::Executor] pro executor that is suppose to
          #   run a given job
          def initialize(executor)
            @executor = executor
            super()
          end

          # Code executed before we schedule this job
          def before_schedule
            executor.before_schedule_periodic
          end

          # Runs the executor periodic action
          def call
            executor.periodic
          end
        end
      end
    end
  end
end
