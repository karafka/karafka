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
