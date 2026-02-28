# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # Deserializers for all the message details (payload, headers, key)
      class Deserializing < Base
        # Routing topic deserializers API. It allows to configure deserializers for various
        # components of each message.
        module Topic
          # This method calls the parent class initializer and then sets up the
          # extra instance variable to nil. The explicit initialization
          # to nil is included as an optimization for Ruby's object shapes system,
          # which improves memory layout and access performance.
          def initialize(...)
            super
            @deserializing = nil
          end

          # Allows for setting all the deserializers with standard defaults
          # @param payload [Object] Deserializer for the message payload
          # @param key [Object] deserializer for the message key
          # @param headers [Object] deserializer for the message headers
          # @param parallel [Boolean] whether to use parallel deserialization (requires Ruby 4.0+)
          def deserializing(
            payload: Karafka::Deserializing::Deserializers::Payload.new,
            key: Karafka::Deserializing::Deserializers::Key.new,
            headers: Karafka::Deserializing::Deserializers::Headers.new,
            parallel: false
          )
            @deserializing ||= Config.new(
              active: true,
              payload: payload,
              key: key,
              headers: headers,
              parallel: parallel
            )
          end

          # Backwards compatible alias for deserializing
          alias deserializers deserializing

          # Supports pre 2.4 format where only payload deserializer could be defined. We do not
          # retire this format because it is not bad when users do not do anything advanced with
          # key or headers
          # @param payload [Object] payload deserializer
          def deserializer(payload)
            deserializing(payload: payload)
          end

          # @return [Boolean] Deserializers are always active
          def deserializing?
            deserializing.active?
          end

          # Backwards compatible alias for deserializing?
          alias deserializers? deserializing?

          # @return [Hash] topic setup hash
          def to_h
            super.merge(
              deserializing: deserializing.to_h
            ).freeze
          end
        end
      end
    end
  end
end
