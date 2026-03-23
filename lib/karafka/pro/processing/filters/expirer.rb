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
        # Expirer for removing too old messages.
        # It never moves offsets in any way and does not impact the processing flow. It always
        # runs `:skip` action.
        class Expirer < Base
          # @param ttl [Integer] maximum age of a message (in ms)
          def initialize(ttl)
            super()

            @ttl = ttl
          end

          # Removes too old messages
          #
          # @param messages [Array<Karafka::Messages::Message>]
          def apply!(messages)
            @applied = false

            # Time on message is in seconds with ms precision, so we need to convert the ttl that
            # is in ms to this format
            border = Time.now.utc - (@ttl / 1_000.to_f)

            messages.delete_if do |message|
              too_old = message.timestamp < border

              @applied = true if too_old

              too_old
            end
          end

          # @return [nil] this filter does not deal with timeouts
          def timeout
            nil
          end
        end
      end
    end
  end
end
