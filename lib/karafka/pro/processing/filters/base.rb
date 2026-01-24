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
    module Processing
      module Filters
        # Base for all the filters.
        # All filters (including custom) need to use this API.
        #
        # Due to the fact, that filters can limit data in such a way, that we need to pause or
        # seek (throttling for example), the api is not just "remove some things from batch" but
        # also provides ways to control the post-filtering operations that may be needed.
        class Base
          # @return [Karafka::Messages::Message, nil] the message that we want to use as a cursor
          #   one to pause or seek or nil if not applicable.
          attr_reader :cursor

          include Karafka::Core::Helpers::Time

          # Initializes the filter as not yet applied
          def initialize
            @applied = false
            @cursor = nil
          end

          # @param messages [Array<Karafka::Messages::Message>] array with messages. Please keep
          #   in mind, this may already be partial due to execution of previous filters.
          def apply!(messages)
            raise NotImplementedError, 'Implement in a subclass'
          end

          # @return [Symbol] filter post-execution action on consumer. Either `:skip`, `:pause` or
          #   `:seek`.
          def action
            :skip
          end

          # @return [Boolean] did this filter change messages in any way
          def applied?
            @applied
          end

          # @return [Integer, nil] default timeout for pausing (if applicable) or nil if not
          # @note Please do not return `0` when your filter is not pausing as it may interact
          #   with other filters that want to pause.
          def timeout
            nil
          end

          # @return [Boolean] should we use the cursor value to mark as consumed. If any of the
          #   filters returns true, we return lowers applicable cursor value (if any)
          def mark_as_consumed?
            false
          end

          # @return [Symbol] `:mark_as_consumed` or `:mark_as_consumed!`. Applicable only if
          #   marking is requested
          def marking_method
            :mark_as_consumed
          end

          # @return [Karafka::Messages::Message, nil] cursor message for marking or nil if no
          #   marking
          def marking_cursor
            cursor
          end
        end
      end
    end
  end
end
