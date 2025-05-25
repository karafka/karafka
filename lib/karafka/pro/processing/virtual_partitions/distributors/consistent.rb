# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module VirtualPartitions
        module Distributors
          # Consistent distributor that ensures messages with the same partition key
          # are always processed in the same virtual partition
          class Consistent < Base
            # @param messages [Array<Karafka::Messages::Message>] messages to distribute
            # @return [Hash<Integer, Array<Karafka::Messages::Message>>] hash with group ids as
            #   keys and message groups as values
            def call(messages)
              messages
                .group_by { |msg| config.reducer.call(config.partitioner.call(msg)) }
                .to_h
            end
          end
        end
      end
    end
  end
end
