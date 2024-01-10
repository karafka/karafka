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
        class Multiplexing < Base
          # Allows for multiplexing setup inside a consumer group definition
          module Proxy
            # @param min [Integer, nil] min multiplexing count or nil to set it to max, effectively
            #   disabling dynamic multiplexing
            # @param max [Integer] max multiplexing count
            # @param boot [Integer] how many listeners should we start during boot by default
            def multiplexing(min: nil, max: 1, boot: nil)
              @target.current_subscription_group_details.merge!(
                multiplexing_min: min || max,
                multiplexing_max: max,
                # Picks half of max by default as long as possible. Otherwise goes with min
                multiplexing_boot: boot || [min || max, (max / 2)].max
              )
            end
          end
        end
      end
    end
  end
end
