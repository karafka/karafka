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
