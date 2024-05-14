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
        class Throttling < Base
          # Topic throttling API extensions
          module Topic
            # @param limit [Integer] max messages to process in an time interval
            # @param interval [Integer] time interval for processing
            def throttling(
              limit: Undefined,
              interval: Undefined
            )
              @throttling ||= Config.new(limit: Float::INFINITY,
                                         interval: 60_000)
              return @throttling if limit == Undefined && interval == Undefined

              @throttling.active = limit != Float::INFINITY
              @throttling.limit = limit
              @throttling.interval = interval

              # If someone defined throttling setup, we need to create appropriate filter for it
              # and inject it via filtering feature
              if @throttling.active?
                factory = ->(*) { Pro::Processing::Filters::Throttler.new(limit, interval) }
                filter(factory)
              end

              @throttling
            end

            # Just an alias for nice API
            #
            # @param args [Array] Anything `#throttling` accepts
            def throttle(**args)
              throttling(**args)
            end

            # @return [Boolean] is a given job throttled
            def throttling?
              throttling.active?
            end

            # @return [Hash] topic with all its native configuration options plus throttling
            def to_h
              super.merge(
                throttling: throttling.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
