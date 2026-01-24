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
    module Cleaner
      module Messages
        # Extensions to the messages batch allowing for automatic cleaning of each message after
        # message is processed.
        #
        # This module is prepended to Karafka::Messages::Messages to add cleaning functionality.
        # The implementation calls super() to maintain compatibility with other libraries that
        # also prepend modules to modify the #each method (e.g., DataDog tracing).
        # @see https://github.com/DataDog/dd-trace-rb/issues/4867
        module Messages
          # @param clean [Boolean] do we want to clean each message after we're done working with
          #   it.
          #
          # @note Cleaning messages after we're done with each of them and did not fail does not
          #   affect any other functionalities. The only thing that is crucial is to make sure,
          #   that if DLQ is used, that we mark each message as consumed when using this API as
          #   otherwise a cleaned message may be dispatched and that should never happen
          #
          # @note This method calls super() to ensure compatibility with other libraries that
          #   may have prepended modules to modify #each behavior. This preserves the method
          #   chain and allows instrumentation libraries to function correctly.
          def each(clean: false, &)
            if clean
              super() do |message|
                yield(message)
                message.clean!
              end
            else
              super(&)
            end
          end
        end
      end
    end
  end
end
