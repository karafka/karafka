# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Multiplexing < Base
          # Adds methods needed for the multiplexing to work
          module SubscriptionGroup
            # @return [Config] multiplexing config
            def multiplexing
              @multiplexing ||= begin
                max = @details.fetch(:multiplexing_max, 1)
                min = @details.fetch(:multiplexing_min, max)
                boot = @details.fetch(:multiplexing_boot, max / 2)
                active = max > 1

                Config.new(active: active, min: min, max: max, boot: boot)
              end
            end

            # @return [Boolean] is multiplexing active
            def multiplexing?
              multiplexing.active?
            end
          end
        end
      end
    end
  end
end
