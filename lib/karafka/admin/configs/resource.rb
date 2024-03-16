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

        private_constant :RESOURCE_TYPES_MAP

        attr_reader :type, :name, :configs

        # @param type [Symbol, Integer] type of resource as a symbol for mapping or integer
        # @param name [String] name of the resource. It's the broker id or topic name
        # @return [Resource]
        def initialize(type:, name:)
          @type = map_type(type)
          @name = name.to_s
          @configs = []

          freeze
        end

        # @return [Hash] resource converted to a hash that rdkafka can work with
        def to_native_hash
          {
            resource_type: RESOURCE_TYPES_MAP.fetch(type),
            resource_name: name,
            configs: configs.map(&:to_h).freeze
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
