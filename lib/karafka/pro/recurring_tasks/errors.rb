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
    module RecurringTasks
      # Recurring Tasks related errors
      module Errors
        # Base for all the recurring tasks errors
        BaseError = Class.new(::Karafka::Errors::BaseError)

        # Raised when older cron manager version is trying to work with newer schema
        IncompatibleSchemaError = Class.new(BaseError)

        # Raised if you use versioned schedule and an existing schedule from Kafka was picked up
        # by a process with older schedule version.
        # This is a safe-guard to protect against a cases where there would be a temporary
        # reassignment of newer schedule data into older process during deployment. It should go
        # away once all processes are rolled.
        IncompatibleScheduleError = Class.new(BaseError)
      end
    end
  end
end
