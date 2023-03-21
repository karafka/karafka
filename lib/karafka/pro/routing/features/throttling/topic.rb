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
            # @param throttler_class [nil, Class] nil if we want to use the default throttler
            #   with the `limit` and `interval` provided via the standard API or a class from
            #   which we may build custom throttlers.
            #   custom throttling class that we can use to provide custom throttling capabilities
            # @param limit [Integer] max messages to process in an time interval
            # @param interval [Integer] time interval for processing
            # @note We allow for direct definition of `limit` and `interval` here despite them
            #   being used only by the default throttler, because we want to provide a simple and
            #   out-of-the-box API that will not force users to define their own throttlers for
            #   simple cases. The `throttler_class` overwrite is suppose to be for more advanced
            #   users.
            def throttling(
              throttler_class: nil,
              limit: Float::INFINITY,
              interval: 60_000
            )
              @throttling ||= Config.new(
                active: !throttler_class.nil? || limit != Float::INFINITY,
                throttler_class: throttler_class,
                limit: limit,
                interval: interval
              )
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
