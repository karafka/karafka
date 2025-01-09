# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
              factor = topics_array.first.subscription_group_details.fetch(:multiplexing_max, 1)

              Array.new(factor) do |i|
                ::Karafka::Routing::Topics.new(
                  i.zero? ? topics_array : topics_array.map(&:dup)
                )
              end
            end
          end
        end
      end
    end
  end
end
