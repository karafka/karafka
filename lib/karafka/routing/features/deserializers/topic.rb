# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # Deserializers for all the message details (payload, headers, key)
      class Deserializers < Base
        # Routing topic deserializers API. It allows to configure deserializers for various
        # components of each message.
        module Topic
          # Allows for setting all the deserializers with standard defaults
          # @param payload [Object] Deserializer for the message payload
          # @param key [Object] deserializer for the message key
          # @param headers [Object] deserializer for the message headers
          def deserializers(
            payload: ::Karafka::Deserializers::Payload.new,
            key: ::Karafka::Deserializers::Key.new,
            headers: ::Karafka::Deserializers::Headers.new
          )
            @deserializers ||= Config.new(
              active: true,
              payload: payload,
              key: key,
              headers: headers
            )
          end

          # Supports pre 2.4 format where only payload deserializer could be defined. We do not
          # retire this format because it is not bad when users do not do anything advanced with
          # key or headers
          # @param payload [Object] payload deserializer
          def deserializer(payload)
            deserializers(payload: payload)
          end

          # @return [Boolean] Deserializers are always active
          def deserializers?
            deserializers.active?
          end

          # @return [Hash] topic setup hash
          def to_h
            super.merge(
              deserializers: deserializers.to_h
            ).freeze
          end
        end
      end
    end
  end
end
