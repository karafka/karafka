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
          # Patches to Karafka OSS
          module Patches
            # Contracts patches
            module Contracts
              # Consumer group contract patches
              module ConsumerGroup
                # Redefines the setup allowing for multiple sgs as long as with different names
                #
                # @param topic [Hash] topic config hash
                # @return [Array] topic unique key for validators
                def topic_unique_key(topic)
                  [
                    topic[:name],
                    topic[:subscription_group_details]
                  ]
                end
              end
            end
          end
        end
      end
    end
  end
end
