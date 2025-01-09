# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ScheduledMessages
      # Scheduled Messages related errors
      module Errors
        # Base for all the recurring tasks errors
        BaseError = Class.new(::Karafka::Errors::BaseError)

        # Raised when the scheduled messages processor is older than the messages we started to
        # receive. In such cases we stop because there may be schema changes.
        IncompatibleSchemaError = Class.new(BaseError)
      end
    end
  end
end
