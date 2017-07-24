# frozen_string_literal: true

module Karafka
  module AttributesMap
    class << self
      # What settings should go where in ruby-kafka
      # @note All other settings will be passed to Kafka.new method invokation.
      #   All elements in this hash are just edge cases
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

      def consumer_attributes
        ((config_adapter.values.flatten - config_adapter[:subscription]) + Karafka::Setup::Config
          ._settings.find {|s| s.name == :kafka}.value.instance_variable_get('@klass').settings).uniq + %i[batch_mode topic_mapper]
      end
    end
  end
end
