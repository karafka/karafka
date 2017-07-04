# frozen_string_literal: true

module Karafka
  module Connection
    # Mapper used to convert our internal settings into ruby-kafka settings
    # Since ruby-kafka has more and more options and there are few "levels" on which
    # we have to apply them (despite the fact, that in Karafka you configure all of it
    # in one place), we have to remap it into what ruby-kafka driver requires
    # @note The good thing about Kafka.new method is that it ignores all options that
    #   do nothing. So we don't have to worry about injecting our internal settings
    #   into the client and breaking stuff
    module ConfigAdapter
      # What settings should go where in ruby-kafka
      # @note All other settings will be passed to Kafka.new method invokation.
      #   All elements in this hash are just edge cases
      EDGE_CASES_MAP = {
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
        ]
      }

      class << self
        # Builds app all the configuration settings for Kafka.new method
        # @param _route [Karafka::Routing::Route] route details
        # @return [Hash] hash with all the settings required by Kafka.new method
        def client(_route)
          # This one is a default that takes all the settings except special
          # cases defined in the map
          settings = {
            logger: ::Karafka.logger,
            client_id: ::Karafka::App.config.name
          }

          kafka_configs.each do |setting_name, setting_value|
            next if EDGE_CASES_MAP[:consumer].include?(setting_name)
            next if EDGE_CASES_MAP[:subscription].include?(setting_name)

            settings[setting_name] = setting_value
          end

          sanitize(settings)
        end

        # Builds app all the configuration settings for kafka#consumer method
        # @param route [Karafka::Routing::Route] route details
        # @return [Hash] hash with all the settings required by Kafka#consumer method
        def consumer(route)
          settings = { group_id: route.group }

          kafka_configs.each do |setting_name, setting_value|
            next unless EDGE_CASES_MAP[:consumer].include?(setting_name)
            next if settings.keys.include?(setting_name)
            settings[setting_name] = setting_value
          end

          sanitize(settings)
        end

        # Builds app all the configuration settings for kafka consumer#subscribe method
        # @param route [Karafka::Routing::Route] route details
        # @return [Hash] hash with all the settings required by kafka consumer#subscribe method
        def subscription(route)
          settings = { start_from_beginning: route.start_from_beginning }

          kafka_configs.each do |setting_name, setting_value|
            next unless EDGE_CASES_MAP[:subscription].include?(setting_name)
            next if settings.keys.include?(setting_name)
            settings[setting_name] = setting_value
          end

          [route.topic, sanitize(settings)]
        end

        private

        # Removes nil containing keys from the final settings
        # @param settings [Hash] settings that may contain nil values
        # @return [Hash] settings without nil using keys (non of karafka options should be nil)
        def sanitize(settings)
          settings.select { |_key, value| !value.nil? }
        end

        # @return [Hash] Kafka config details as a hash
        def kafka_configs
          ::Karafka::App.config.kafka.to_h
        end
      end
    end
  end
end
