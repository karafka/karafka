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
    module Processing
      # Pro partitioner that can distribute work based on the virtual partitioner settings
      class Partitioner < ::Karafka::Processing::Partitioner
        # @param topic [String] topic name
        # @param messages [Array<Karafka::Messages::Message>] karafka messages
        # @param coordinator [Karafka::Pro::Processing::Coordinator] processing coordinator that
        #   will be used with those messages
        # @yieldparam [Integer] group id
        # @yieldparam [Array<Karafka::Messages::Message>] karafka messages
        def call(topic, messages, coordinator)
          ktopic = @subscription_group.topics.find(topic)

          # We only partition work if we have:
          # - a virtual partitioner
          # - more than one thread to process the data
          # - collective is not collapsed via coordinator
          #
          # With one thread it is not worth partitioning the work as the work itself will be
          # assigned to one thread (pointless work)
          #
          # We collapse the partitioning on errors because we "regain" full ordering on a batch
          # that potentially contains the data that caused the error.
          #
          # This is great because it allows us to run things without the parallelization that adds
          # a bit of uncertainty and allows us to use DLQ and safely skip messages if needed.
          if ktopic.virtual_partitions? &&
             ktopic.virtual_partitions.max_partitions > 1 &&
             !coordinator.collapsed?
            # We need to reduce it to the max concurrency, so the group_id is not a direct effect
            # of the end user action. Otherwise the persistence layer for consumers would cache
            # it forever and it would cause memory leaks
            #
            # This also needs to be consistent because the aggregation here needs to warrant, that
            # the same partitioned message will always be assigned to the same virtual partition.
            # Otherwise in case of a window aggregation with VP spanning across several polls, the
            # data could not be complete.
            groupings = messages.group_by do |msg|
              key = ktopic.virtual_partitions.partitioner.call(msg).to_s.sum

              key % ktopic.virtual_partitions.max_partitions
            end

            groupings.each do |key, messages_group|
              yield(key, messages_group)
            end
          else
            # When no virtual partitioner, works as regular one
            yield(0, messages)
          end
        end
      end
    end
  end
end
