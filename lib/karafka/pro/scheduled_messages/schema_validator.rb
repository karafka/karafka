# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ScheduledMessages
      # Validator that checks if we can process this scheduled message
      # If we encounter message that has a schema version higher than our process is aware of
      # we raise and error and do not process. This is to make sure we do not deal with messages
      # that are not compatible in case of schema changes.
      module SchemaValidator
        class << self
          # Check if we can work with this schema message and raise error if not.
          #
          # @param message [Karafka::Messages::Message]
          def call(message)
            message_version = message.headers['schedule_schema_version']

            return if message_version <= ScheduledMessages::SCHEMA_VERSION

            raise Errors::IncompatibleSchemaError, message_version
          end
        end
      end
    end
  end
end
