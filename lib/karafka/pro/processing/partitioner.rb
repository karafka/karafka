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

          @concurrency ||= ::Karafka::App.config.concurrency

          # We only partition work if we have a virtual partitioner and more than one thread to
          # process the data. With one thread it is not worth partitioning the work as the work
          # itself will be assigned to one thread (pointless work)
          if ktopic.virtual_partitioner? && @concurrency > 1
            messages
              .group_by { |msg| ktopic.virtual_partitioner.call(msg).hash.abs % @concurrency }
              .each { |group_id, messages_group| yield(group_id, messages_group) }
          else
            # When no virtual partitioner, works as regular one
            yield(0, messages)
          end
        end
      end
    end
  end
end
