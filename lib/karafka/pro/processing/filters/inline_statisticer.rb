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
    module Processing
      module Filters
        # Ensures that we only start processing of data when inline statistics are available
        #
        # If there are no statistics available for a given topic partition, we will pause the
        # processing and try again in few seconds. Since statistics should become present after
        # few seconds from boot, this should be enough for us to get them.
        #
        # @note Do NOT use without inline statistics enabled as it will crash
        class InlineStatisticer < Base
          # Pause delay time when no statistics are available for the topic partition
          DELAY_ON_NO_STATISTICS = 5_000

          private_constant :DELAY_ON_NO_STATISTICS

          # @param messages [Array<Karafka::Messages::Message>]
          def apply!(messages)
            @cursor = messages.first
            @applied = !::Karafka::Monitoring::InlineStatistics::Tracker.exists?(
              @cursor.topic,
              @cursor.partition
            )
          end

          # @return [Integer] timeout delay in ms
          def timeout
            DELAY_ON_NO_STATISTICS
          end

          # @return [Symbol] pause if no statistics, otherwise just work
          def action
            applied? ? :pause : :skip
          end
        end
      end
    end
  end
end
