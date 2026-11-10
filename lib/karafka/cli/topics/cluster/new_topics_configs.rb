# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      module Cluster
        # Topic configuration names the cluster does not know, found without describing a topic.
        #
        # We ask the cluster to only validate the creation of a topic, so nothing is created. The
        # cluster names only one unknown config name when the validation fails, so we then
        # validate each config on its own.
        class NewTopicsConfigs
          include Helpers::ConfigImporter.new(
            max_wait_time: %i[admin max_wait_time]
          )

          # Start of the error message of the cluster for a config name it does not know
          UNKNOWN_NAME = "Unknown topic config name"

          private_constant :UNKNOWN_NAME

          # @param admin [Karafka::Connection::Proxy] admin client
          def initialize(admin)
            @admin = admin
          end

          # @param topic_name [String] name of a topic that does not exist in the cluster
          # @param configs [Hash{String => String}] configs names with values
          # @return [Array<String>] names of the configs the cluster does not know
          def unknown(topic_name, configs)
            return [] if known?(topic_name, configs)

            configs.reject { |name, value| known?(topic_name, name => value) }.keys
          end

          private

          # @param topic_name [String] name of a topic that does not exist in the cluster
          # @param configs [Hash{String => String}] configs names with values
          # @return [Boolean] false only when the cluster does not know a config name
          # @note The cluster checks config names before values, so an invalid value of a known
          #   config does not hide an unknown name
          def known?(topic_name, configs)
            @admin
              .create_topic(topic_name, -1, -1, configs, validate_only: true)
              .wait(max_wait_timeout_ms: max_wait_time)

            true
          rescue Rdkafka::RdkafkaError => e
            raise unless e.code == :invalid_config

            !e.broker_message.to_s.start_with?(UNKNOWN_NAME)
          end
        end
      end
    end
  end
end
