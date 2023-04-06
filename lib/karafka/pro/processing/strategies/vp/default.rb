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
      module Strategies
        # VP starting strategies
        module Vp
          # Just Virtual Partitions enabled
          module Default
            # This flow is exactly the same as the default one because the default one is wrapper
            # with `coordinator#on_finished`
            include Strategies::Default

            # Features for this strategy
            FEATURES = %i[
              virtual_partitions
            ].freeze

            # @return [Boolean] is the virtual processing collapsed in the context of given
            #   consumer.
            def collapsed?
              coordinator.collapsed?
            end

            # @return [Boolean] true if any of virtual partition we're operating in the entangled
            #   mode has already failed and we know we are failing collectively.
            #   Useful for early stop to minimize number of reprocessings.
            #
            # @note We've named it `#failing?` instead of `#failure?`  because it aims to be used
            #   from within virtual partitions where we want to have notion of collective failing
            #   not just "local" to our processing. We "are" failing with other virtual partitions
            #   raising an error, but locally we are still processing.
            def failing?
              coordinator.failure?
            end
          end
        end
      end
    end
  end
end
