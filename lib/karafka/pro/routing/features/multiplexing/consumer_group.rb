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
          # Expansions of routing for multiplexing support
          module ConsumerGroup
            # Assigns the current subscription group id based on the defined one and allows for
            # further topic definition
            # @param name [String, Symbol] name of the current subscription group
            # @param multiplex [Integer] how many subscription groups initialize out of this
            #   definition
            # @param block [Proc] block that may include topics definitions
            def subscription_group=(name = SubscriptionGroup.id, multiplex: 1, &block)
              multiplex.times do |i|
                super(
                  multiplex > 1 ? "#{name}_multiplex_#{i}" : name.to_s,
                  &block
                )
              end
            end
          end
        end
      end
    end
  end
end
