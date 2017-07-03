module Karafka
  module Connection
    module ConfigMapper
      MAP = {
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

      def client
        # This one is a default that takes all the settings except special
        # cases defined in the map
        settings = {
          logger: ::Karafka.logger,
          client_id: ::Karafka::App.config.name,
          seed_brokers: ::Karafka::App.config.kafka.hosts
        }

        ::Karafka::App.config.kafka.to_h.each do |setting_name, setting_value|
          next if MAP[:consumer].include?(setting_name)
          next if MAP[:subscription].include?(setting_name)

          settings[setting_name] = setting_value
        end

        settings
      end

      def consumer(route)
        settings = { group_id: route.group }

        ::Karafka::App.config.kafka.to_h.each do |setting_name, setting_value|
          next unless MAP[:consumer].include?(setting_name)
          settings[setting_name] = setting_value
        end

        settings
      end

      def subscription(route)
        settings = {}

        ::Karafka::App.config.kafka.to_h.each do |setting_name, setting_value|
          next unless MAP[:consumer].include?(setting_name)
          settings[setting_name] = setting_value
        end

        [route.topic, settings]
      end
    end
  end
end
