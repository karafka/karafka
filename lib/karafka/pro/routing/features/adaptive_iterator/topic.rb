# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class AdaptiveIterator < Base
          # Topic extension allowing us to enable and configure adaptive iterator
          module Topic
            # @param active [Boolean] should we use the automatic adaptive iterator
            # @param safety_margin [Integer]
            #   How big of a margin we leave ourselves so we can safely communicate back with
            #   Kafka, etc. We stop and seek back when we've burned 85% of the time by default.
            #   We leave 15% of time for post-processing operations so we have space before we
            #   hit max.poll.interval.ms.
            # @param marking_method [Symbol] If we should, how should we mark
            # @param clean_after_yielding [Boolean]  Should we clean post-yielding via the
            #   cleaner API
            def adaptive_iterator(
              active: false,
              safety_margin: 10,
              marking_method: :mark_as_consumed,
              clean_after_yielding: true
            )
              @adaptive_iterator ||= Config.new(
                active: active,
                safety_margin: safety_margin,
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
