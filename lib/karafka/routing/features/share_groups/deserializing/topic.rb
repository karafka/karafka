# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        class Deserializing < Base
          # Routing topic deserializers API. It allows to configure deserializers for various
          # components of each message.
          module Topic
            # This method sets up the extra instance variable to nil before calling
            # the parent class initializer. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              @deserializing = nil
              super
            end

            # Allows for setting all the deserializers with standard defaults
            # @param payload [Object] Deserializer for the message payload
            # @param key [Object] deserializer for the message key
            # @param headers [Object] deserializer for the message headers
            def deserializing(
              payload: Karafka::Deserializing::Deserializers::Payload.new,
              key: Karafka::Deserializing::Deserializers::Key.new,
              headers: Karafka::Deserializing::Deserializers::Headers.new
            )
              @deserializing ||= Config.new(
                active: true,
                payload: payload,
                key: key,
                headers: headers
              )
            end

            # Backwards compatible alias for deserializing
            alias_method :deserializers, :deserializing

            # Supports pre 2.4 format where only payload deserializer could be defined. We do not
            # retire this format because it is not bad when users do not do anything advanced with
            # key or headers
            # @param payload [Object] payload deserializer
            def deserializer(payload)
              deserializing(payload: payload)
            end

            # @return [Boolean] Deserializing is always active
            def deserializing?
              deserializing.active?
            end

            # Backwards compatible alias for deserializing?
            alias_method :deserializers?, :deserializing?

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
end
