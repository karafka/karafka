# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
