# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
