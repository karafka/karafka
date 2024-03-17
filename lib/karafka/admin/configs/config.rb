# frozen_string_literal: true

module Karafka
  module Admin
    module Configs
      # Represents a single config entry that is related to a resource
      class Config
        attr_reader :name, :value, :synonyms

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
          synonyms: []
        )
          @name = name
          @value = value
          @synonyms = []
          @default = default
          @read_only = read_only
          @sensitive = sensitive
          @synonym = synonym
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
        def to_native_hash = {
          name: name,
          value: value
        }.freeze
      end
    end
  end
end
