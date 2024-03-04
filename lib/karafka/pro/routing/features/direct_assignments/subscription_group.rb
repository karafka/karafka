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
                .map { |topic| [topic.subscription_name, topic.direct_assignments.partitions] }
                .to_h
                .tap { |topics| return false if topics.empty? }
                .then { |topics| Iterator::Expander.new.call(topics) }
                .then { |topics| Iterator::TplBuilder.new(consumer, topics).call }
            end
          end
        end
      end
    end
  end
end
