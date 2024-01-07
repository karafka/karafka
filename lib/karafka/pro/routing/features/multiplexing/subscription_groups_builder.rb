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
          # Expands the builder to multiply multiplexed groups
          module SubscriptionGroupsBuilder
            # Takes into consideration multiplexing and builds the more groups
            #
            # @param topics_array [Array<Routing::Topic>] group of topics that have the same
            #   settings and can use the same connection
            # @return [Array<Array<Routing::Topics>>] expanded groups
            def expand(topics_array)
              factor = topics_array.first.subscription_group_details.fetch(:multiplexing_count, 1)

              Array.new(factor) do |i|
                ::Karafka::Routing::Topics.new(i.zero? ? topics_array : topics_array.map(&:dup))
              end
            end
          end
        end
      end
    end
  end
end
