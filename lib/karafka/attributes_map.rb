# frozen_string_literal: true

module Karafka
  # Both Karafka and Ruby-Kafka contain a lot of settings that can be applied on multiple
  # levels. In Karafka that is on consumer group and on topic level. In Ruby-Kafka it
  # is on consumer, subscription and consumption levels. In order to maintain an order
  # in managing those settings, this odule was created. It contains details on what setting
  # where should go and which layer (both on Karafka and Ruby-Kafka) is responsible for
  # setting it and sending it forward
  # @note Settings presented here cover all the settings that are being used across Karafka
  module AttributesMap
    class << self
      # What settings should go where in ruby-kafka
      # @note All other settings will be passed to Kafka.new method invokation.
      #   All elements in this hash are just edge cases
      # @return [Hash] hash with proper sections on what to proxy where in Ruby-Kafka
      def config_adapter
        {
          consumer: %i[
            session_timeout
            offset_commit_interval
            offset_commit_threshold
            offset_retention_time
            heartbeat_interval
          ],
          subscription: %i[
            start_from_beginning
            max_bytes_per_partition
          ],
          consuming: %i[
            min_bytes
            max_wait_time
          ],
          # All the options that are under kafka config namespace, but are not used
          # directly with kafka api, but from the Karafka user perspective, they are
          # still related to kafka. They should not be proxied anywhere
          ignored: %i[
            reconnect_timeout
          ]
        }
      end

      # @return [Array<Symbol>] properties that can be set on a per topic level
      def topic_attributes
        (config_adapter[:subscription] + %i[
          name
          controller
          worker
          inline_mode
          parser
          interchanger
          responder
        ]).uniq
      end

      # @return [Array<Symbol>] properties that can be set on a per consumer group level
      # @note Note that there are settings directly extracted from the config kafka namespace
      #   I did this that way, so I won't have to repeat same setting keys over and over again
      #   Thanks to this solution, if any new setting is available for ruby-kafka, we just need
      #   to add it to our configuration class and it will be handled automatically.
      def consumer_group_attributes
        defined_settings = config_adapter.values.flatten - config_adapter[:subscription]
        dynamically_proxied = Karafka::Setup::Config
          ._settings
          .find { |s| s.name == :kafka }
          .value
          .instance_variable_get('@klass').settings

        (defined_settings + dynamically_proxied).uniq + %i[batch_mode topic_mapper]
      end
    end
  end
end
