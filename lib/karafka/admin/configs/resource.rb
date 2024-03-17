# frozen_string_literal: true

module Karafka
  module Admin
    module Configs
      # Represents a single resource in the context of configuration management
      class Resource
        # Types of resources that have workable configs.
        RESOURCE_TYPES_MAP = {
          # use when you want to assign acl to a given topic
          topic: Rdkafka::Bindings::RD_KAFKA_RESOURCE_TOPIC,
          # use when you want to assign acl to a given broker
          broker: Rdkafka::Bindings::RD_KAFKA_RESOURCE_BROKER
        }.freeze

        # Map for operations we may perform on the resource configs
        OPERATIONS_TYPES_MAP = {
          set: Rdkafka::Bindings::RD_KAFKA_ALTER_CONFIG_OP_TYPE_SET,
          delete: Rdkafka::Bindings::RD_KAFKA_ALTER_CONFIG_OP_TYPE_DELETE,
          append: Rdkafka::Bindings::RD_KAFKA_ALTER_CONFIG_OP_TYPE_APPEND,
          subtract: Rdkafka::Bindings::RD_KAFKA_ALTER_CONFIG_OP_TYPE_SUBTRACT
        }.freeze

        private_constant :RESOURCE_TYPES_MAP, :OPERATIONS_TYPES_MAP

        attr_reader :type, :name, :configs

        # @param type [Symbol, Integer] type of resource as a symbol for mapping or integer
        # @param name [String] name of the resource. It's the broker id or topic name
        # @return [Resource]
        def initialize(type:, name:)
          @type = map_type(type)
          @name = name.to_s
          @configs = []
          @operations = Hash.new { |h, k| h[k] = [] }

          freeze
        end

        OPERATIONS_TYPES_MAP.each do |op_name, op_value|
          # Adds an outgoing operation to a given resource of a given type
          # Useful since we alter in batches and not one at a time
          class_eval <<~RUBY, __FILE__, __LINE__ + 1
            # @param name [String] name of the config to alter
            # @param value [String] value of the config
            def #{op_name}(name, value #{op_name == :delete ? ' = nil' : ''})
              @operations[#{op_value}] << Config.new(name: name, value: value.to_s)
            end
          RUBY
        end

        # @return [Hash] resource converted to a hash that rdkafka can work with
        # @note Configs include the operation type and are expected to be used only for the
        #   incremental alter API.
        def to_native_hash
          configs_with_operations = []

          @operations.each do |op_type, configs|
            configs.each do |config|
              configs_with_operations << config.to_native_hash.merge(op_type: op_type)
            end
          end

          {
            resource_type: RESOURCE_TYPES_MAP.fetch(type),
            resource_name: name,
            configs: configs_with_operations
          }.freeze
        end

        private

        # Recognizes whether the type is provided and remaps it to a symbol representation if
        # needed
        #
        # @param type [Symbol, Integer]
        # @return [Symbol]
        def map_type(type)
          inverted = RESOURCE_TYPES_MAP.invert

          return inverted[type] if inverted.key?(type)

          RESOURCE_TYPES_MAP.fetch(type) ? type : nil
        end
      end
    end
  end
end
