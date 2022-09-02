# frozen_string_literal: true

module Karafka
  module Routing
    # rdkafka allows us to group topics subscriptions when they have same settings.
    # This builder groups topics from a single consumer group into subscription groups that can be
    # subscribed with one rdkafka connection.
    # This way we save resources as having several rdkafka consumers under the hood is not the
    # cheapest thing in a bigger system.
    #
    # In general, if we can, we try to subscribe to as many topics with one rdkafka connection as
    # possible, but if not possible, we divide.
    class SubscriptionGroupsBuilder
      # Keys used to build up a hash for subscription groups distribution.
      # In order to be able to use the same rdkafka connection for several topics, those keys need
      # to have same values.
      DISTRIBUTION_KEYS = %i[
        kafka
        max_messages
        max_wait_time
        initial_offset
        subscription_group
      ].freeze

      private_constant :DISTRIBUTION_KEYS

      # @param topics [Karafka::Routing::Topics] all the topics based on which we want to build
      #   subscription groups
      # @return [Array<SubscriptionGroup>] all subscription groups we need in separate threads
      def call(topics)
        topics
          .map { |topic| [checksum(topic), topic] }
          .group_by(&:first)
          .values
          .map { |value| value.map(&:last) }
          .map { |topics_array| Routing::Topics.new(topics_array) }
          .map { |grouped_topics| SubscriptionGroup.new(grouped_topics) }
      end

      private

      # @param topic [Karafka::Routing::Topic] topic for which we compute the grouping checksum
      # @return [Integer] checksum that we can use to check if topics have the same set of
      #   settings based on which we group
      def checksum(topic)
        accu = {}

        DISTRIBUTION_KEYS.each { |key| accu[key] = topic.public_send(key) }

        accu.hash
      end
    end
  end
end
