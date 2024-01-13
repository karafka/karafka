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
