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
    module Processing
      # Pro partitioner that can distribute work based on the virtual partitioner settings
      class Partitioner < ::Karafka::Processing::Partitioner
        # @param topic [String] topic name
        # @param messages [Array<Karafka::Messages::Message>] karafka messages
        # @yieldparam [Integer] group id
        # @yieldparam [Array<Karafka::Messages::Message>] karafka messages
        def call(topic, messages)
          ktopic = @subscription_group.topics.find(topic)

          # We only partition work if we have a virtual partitioner and more than one thread to
          # process the data. With one thread it is not worth partitioning the work as the work
          # itself will be assigned to one thread (pointless work)
          if ktopic.virtual_partitions? && ktopic.virtual_partitions.max_partitions > 1
            # We need to reduce it to number of threads, so the group_id is not a direct effect
            # of the end user action. Otherwise the persistence layer for consumers would cache
            # it forever and it would cause memory leaks
            groupings = messages
                        .group_by { |msg| ktopic.virtual_partitions.partitioner.call(msg) }
                        .values

            # Reduce the number of virtual partitions to a size that matches the max_partitions
            # As mentioned above we cannot use the partitioning keys directly as it could cause
            # memory leaks
            #
            # The algorithm here is simple, we assume that the most costly in terms of processing,
            # will be processing of the biggest group and we reduce the smallest once to have
            # max of groups equal to max_partitions
            while groupings.size > ktopic.virtual_partitions.max_partitions
              groupings.sort_by! { |grouping| -grouping.size }

              # Offset order needs to be maintained for virtual partitions
              groupings << (groupings.pop + groupings.pop).sort_by!(&:offset)
            end

            groupings.each_with_index { |messages_group, index| yield(index, messages_group) }
          else
            # When no virtual partitioner, works as regular one
            yield(0, messages)
          end
        end
      end
    end
  end
end
