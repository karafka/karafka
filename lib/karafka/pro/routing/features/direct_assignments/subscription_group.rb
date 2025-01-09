# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Alterations to the direct assignments that allow us to do stable direct assignments
        # without working with consumer groups dynamic assignments
        class DirectAssignments < Base
          # Extension allowing us to select correct subscriptions and assignments based on the
          # expanded routing setup
          module SubscriptionGroup
            # @return [false, Array<String>] false if we do not have any subscriptions or array
            #   with all the subscriptions for given subscription group
            def subscriptions
              topics
                .select(&:active?)
                .reject { |topic| topic.direct_assignments.active? }
                .map(&:subscription_name)
                .then { |subscriptions| subscriptions.empty? ? false : subscriptions }
            end

            # @param consumer [Karafka::Connection::Proxy] consumer for expanding  the partition
            #   knowledge in case of certain topics assignments
            # @return [Rdkafka::Consumer::TopicPartitionList] final tpl for assignments
            def assignments(consumer)
              topics
                .select(&:active?)
                .select { |topic| topic.direct_assignments.active? }
                .map { |topic| build_assignments(topic) }
                .to_h
                .tap { |topics| return false if topics.empty? }
                .then { |topics| Iterator::Expander.new.call(topics) }
                .then { |topics| Iterator::TplBuilder.new(consumer, topics).call }
            end

            private

            # Builds assignments based on all the routing stuff. Takes swarm into consideration.
            #
            # @param topic [Karafka::Routing::Topic]
            # @return [Array<String, Hash>]
            def build_assignments(topic)
              node = Karafka::App.config.swarm.node

              standard_setup = [
                topic.subscription_name,
                topic.direct_assignments.partitions
              ]

              return standard_setup unless node
              # Unless user explicitly assigned particular partitions to particular nodes, we just
              # go with full regular assignments
              return standard_setup unless topic.swarm.nodes.is_a?(Hash)

              [
                topic.subscription_name,
                topic.swarm.nodes.fetch(node.id).map { |partition| [partition, true] }.to_h
              ]
            end
          end
        end
      end
    end
  end
end
