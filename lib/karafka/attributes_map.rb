# frozen_string_literal: true

module Karafka
  # Both Karafka and Ruby-Kafka contain a lot of settings that can be applied on multiple
  # levels. In Karafka that is on consumer group and on the topic level. In Ruby-Kafka it
  # is on consumer, subscription and consumption levels. In order to maintain an order
  # in managing those settings, this module was created. It contains details on what setting
  # where should go and which layer (both on Karafka and Ruby-Kafka) is responsible for
  # setting it and sending it forward
  # @note Settings presented here cover all the settings that are being used across Karafka
  module AttributesMap
    class << self
      # @return [Array<Symbol>] properties that can be set on a per topic level
      def topic
        %i[
          kafka
          deserializer
        ]
      end

      # @return [Array<Symbol>] properties that can be set on a per consumer group level
      # @note Note that there are settings directly extracted from the config kafka namespace
      #   I did this that way, so I won't have to repeat same setting keys over and over again
      #   Thanks to this solution, if any new setting is available for ruby-kafka, we just need
      #   to add it to our configuration class and it will be handled automatically.
      def consumer_group
        %i[
          kafka
          deserializer
          max_messages
          max_wait_time
          max_poll_retries
        ]
      end
    end
  end
end
