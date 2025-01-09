# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
              limit: Float::INFINITY,
              interval: 60_000
            )
              # Those settings are used for validation
              @throttling ||= begin
                config = Config.new(
                  active: limit != Float::INFINITY,
                  limit: limit,
                  interval: interval
                )

                # If someone defined throttling setup, we need to create appropriate filter for it
                # and inject it via filtering feature
                if config.active?
                  factory = ->(*) { Pro::Processing::Filters::Throttler.new(limit, interval) }
                  filter(factory)
                end

                config
              end
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
