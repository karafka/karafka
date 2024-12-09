# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
