# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
            # @param scale_delay [Integer] number of ms of delay before applying any scale
            #   operation to a consumer group
            def multiplexing(min: nil, max: 1, boot: nil, scale_delay: 60_000)
              @target.current_subscription_group_details.merge!(
                multiplexing_min: min || max,
                multiplexing_max: max,
                # Picks half of max by default as long as possible. Otherwise goes with min
                multiplexing_boot: boot || [min || max, (max / 2)].max,
                multiplexing_scale_delay: scale_delay
              )
            end
          end
        end
      end
    end
  end
end
