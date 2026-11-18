# frozen_string_literal: true

module Karafka
  class Admin
    class Configs
      # Represents a single config entry that is related to a resource
      class Config
        # Maps the numeric librdkafka config source codes to Ruby symbols. Anything we do
        # not recognize normalizes to `:unknown_config`.
        SOURCES = {
          Rdkafka::Bindings::RD_KAFKA_CONFIG_SOURCE_UNKNOWN_CONFIG => :unknown_config,
          Rdkafka::Bindings::RD_KAFKA_CONFIG_SOURCE_DYNAMIC_TOPIC_CONFIG => :dynamic_topic_config,
          Rdkafka::Bindings::RD_KAFKA_CONFIG_SOURCE_DYNAMIC_BROKER_CONFIG => :dynamic_broker_config,
          Rdkafka::Bindings::RD_KAFKA_CONFIG_SOURCE_DYNAMIC_DEFAULT_BROKER_CONFIG =>
            :dynamic_default_broker_config,
          Rdkafka::Bindings::RD_KAFKA_CONFIG_SOURCE_STATIC_BROKER_CONFIG => :static_broker_config,
          Rdkafka::Bindings::RD_KAFKA_CONFIG_SOURCE_DEFAULT_CONFIG => :default_config,
          Rdkafka::Bindings::RD_KAFKA_CONFIG_SOURCE_GROUP_CONFIG => :consumer_group_config
        }.freeze

        private_constant :SOURCES

        attr_reader :name, :value, :synonyms

        # @return [Symbol] where the value comes from: `:dynamic_topic_config` (set on the topic),
        #   `:dynamic_broker_config`, `:dynamic_default_broker_config`, `:static_broker_config`,
        #   `:default_config` (built-in default), `:consumer_group_config` or `:unknown_config`
        attr_reader :source

        class << self
          # Creates a single config entry from the Rdkafka config result entry
          #
          # @param rd_kafka_config [Rdkafka::Admin::ConfigBindingResult]
          # @return [Config]
          def from_rd_kafka(rd_kafka_config)
            new(
              name: rd_kafka_config.name,
              value: rd_kafka_config.value,
              read_only: rd_kafka_config.read_only,
              default: rd_kafka_config.default,
              sensitive: rd_kafka_config.sensitive,
              synonym: rd_kafka_config.synonym,
              source: SOURCES.fetch(rd_kafka_config.source, :unknown_config),
              synonyms: rd_kafka_config.synonyms.map do |rd_kafka_synonym|
                from_rd_kafka(rd_kafka_synonym)
              end
            )
          end
        end

        # Creates new config instance either for reading or as part of altering operation
        #
        # @param name [String] config name
        # @param value [String] config value
        # @param default [Integer] 1 if default
        # @param read_only [Integer] 1 if read only
        # @param sensitive [Integer] 1 if sensitive
        # @param synonym [Integer] 1 if synonym
        # @param source [Symbol] where the value comes from
        # @param synonyms [Array] given config synonyms (if any)
        #
        # @note For alter operations only `name` and `value` are needed
        def initialize(
          name:,
          value:,
          default: -1,
          read_only: -1,
          sensitive: -1,
          synonym: -1,
          source: :unknown_config,
          synonyms: []
        )
          @name = name
          @value = value
          @synonyms = []
          @default = default
          @read_only = read_only
          @sensitive = sensitive
          @synonym = synonym
          @source = source
          @synonyms = synonyms
        end

        # @return [Boolean] Is the config property is set to its default value on the broker
        def default? = @default.positive?

        # @return [Boolean] Is the config property is read-only on the broker
        def read_only? = @read_only.positive?

        # @return [Boolean] if the config property contains sensitive information (such as
        #   security configuration
        def sensitive? = @sensitive.positive?

        # @return [Boolean] is this entry is a synonym
        def synonym? = @synonym.positive?

        # @return [Hash] hash that we can use to operate with rdkafka
        def to_native_hash
          {
            name: name,
            value: value
          }.freeze
        end
      end
    end
  end
end
