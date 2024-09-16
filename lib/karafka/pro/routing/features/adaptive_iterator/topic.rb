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
    module Routing
      module Features
        class AdaptiveIterator < Base
          # Topic extension allowing us to enable and configure adaptive iterator
          module Topic
            # @param safety_margin [Integer]
            #   How big of a margin we leave ourselves so we can safely communicate back with
            #   Kafka, etc. We stop and seek back when we've burned 85% of the time by default.
            #   We leave 15% of time for post-processing operations so we have space before we
            #   hit max.poll.interval.ms.
            # @param adaptive_margin [Boolean]
            #   This computes the cost of processing based on first processed message. If the cost
            #   of processing despite being below the safety margin would not allow us to process
            #   the message, we will not
            # @param mark_after_yielding [Boolean] Should we mark after each message
            # @param marking_method [Symbol] If we should, how should we mark
            # @param clean_after_yielding [Boolean]  Should we clean post-yielding via the
            #   cleaner API
            def adaptive_iterator(
              safety_margin: 15,
              adaptive_margin: true,
              mark_after_yielding: true,
              marking_method: :mark_as_consumed,
              clean_after_yielding: true
            )
              @adaptive_iterator ||= Config.new(
                active: true,
                safety_margin: safety_margin,
                adaptive_margin: adaptive_margin,
                mark_after_yielding: mark_after_yielding,
                marking_method: marking_method,
                clean_after_yielding: clean_after_yielding
              )
            end

            # @return [Boolean] Is adaptive iterator active. It is always `true`, since we use it
            #   via explicit messages batch wrapper
            def adaptive_iterator?
              adaptive_iterator.active?
            end

            # @return [Hash] topic with all its native configuration options plus poll guarding
            #   setup configuration.
            def to_h
              super.merge(
                adaptive_iterator: adaptive_iterator.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
