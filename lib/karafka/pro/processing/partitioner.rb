# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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

          vps = ktopic.virtual_partitions

          # We only partition work if we have:
          # - a virtual partitioner
          # - more than one thread to process the data
          # - collective is not collapsed via coordinator
          # - none of the partitioner executions raised an error
          #
          # With one thread it is not worth partitioning the work as the work itself will be
          # assigned to one thread (pointless work)
          #
          # We collapse the partitioning on errors because we "regain" full ordering on a batch
          # that potentially contains the data that caused the error.
          #
          # This is great because it allows us to run things without the parallelization that adds
          # a bit of uncertainty and allows us to use DLQ and safely skip messages if needed.
          if vps.active? && vps.max_partitions > 1 && !coordinator.collapsed?
            # If we cannot virtualize even one message from a given batch due to user errors, we
            # reduce the whole set into one partition and emit error. This should still allow for
            # user flow but should mitigate damages by not virtualizing
            begin
              groupings = vps.distributor.call(messages)
            rescue StandardError => e
              # This should not happen. If you are seeing this it means your partitioner code
              # failed and raised an error. We highly recommend mitigating partitioner level errors
              # on the user side because this type of collapse should be considered a last resort
              Karafka.monitor.instrument(
                'error.occurred',
                caller: self,
                error: e,
                messages: messages,
                type: 'virtual_partitions.partitioner.error'
              )

              groupings = { 0 => messages }
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
