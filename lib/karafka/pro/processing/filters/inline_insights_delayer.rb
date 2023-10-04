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
        # Delayer that checks if we have appropriate insights available. If not, pauses for
        # 5 seconds so the insights can be loaded from the broker.
        #
        # In case it would take more than five seconds to load insights, it will just pause again
        #
        # This filter ensures, that we always have inline insights that a consumer can use
        #
        # It is relevant in most cases only during the process start, when first poll may not
        # yield statistics yet but will give some data.
        class InlineInsightsDelayer < Base
          # Minimum how long should we pause when there are no metrics
          PAUSE_TIMEOUT = 5_000

          private_constant :PAUSE_TIMEOUT

          # @param topic [Karafka::Routing::Topic]
          # @param partition [Integer] partition
          def initialize(topic, partition)
            super()
            @topic = topic
            @partition = partition
          end

          # Pauses if inline insights would not be available. Does nothing otherwise
          #
          # @param messages [Array<Karafka::Messages::Message>]
          def apply!(messages)
            @applied = false
            @cursor = messages.first

            # Nothing to do if there were no messages
            # This can happen when we chain filters
            return unless @cursor

            insights = ::Karafka::Processing::InlineInsights::Tracker.find(
              @topic,
              @partition
            )

            # If insights are available, also nothing to do here and we can just process
            return unless insights.empty?

            messages.clear

            @applied = true
          end

          # @return [Integer] ms timeout in case of pause
          def timeout
            @cursor && applied? ? PAUSE_TIMEOUT : 0
          end

          # Pause when we had to back-off or skip if delay is not needed
          def action
            applied? ? :pause : :skip
          end
        end
      end
    end
  end
end
