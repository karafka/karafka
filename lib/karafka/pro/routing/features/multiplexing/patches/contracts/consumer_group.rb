# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
