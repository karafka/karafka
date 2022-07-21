# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    # Pro routing components
    module Routing
      # Routing extensions for builder to be able to validate Pro components correct usage
      module BuilderExtensions
        # Validate consumer groups with pro contracts
        # @param block [Proc] routing defining block
        def draw(&block)
          super

          each do |consumer_group|
            ::Karafka::Pro::Contracts::ConsumerGroup.new.validate!(consumer_group.to_h)
          end
        end
      end
    end
  end
end
