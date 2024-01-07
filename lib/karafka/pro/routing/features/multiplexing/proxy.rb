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
            # @param count [Integer] max multiplexing count
            # @param dynamic [Boolean] can we manage connections dynamically depending on the
            #   state of subscriptions
            def multiplexing(count: 1, dynamic: false)
              @target.current_subscription_group_details.merge!(
                multiplexing_count: count,
                multiplexing_dynamic: dynamic
              )
            end
          end
        end
      end
    end
  end
end
