# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ConsumerGroups
        class Deserializers < Base
          # Routing topic deserializers API. It allows to configure deserializers for various
          # components of each message.
          module Topic
            # Default argument marker, so the default deserializers are built only once instead of
            # on every call (this method is called for each consumed message)
            UNSET = Object.new.freeze

            private_constant :UNSET

            # This method sets up the extra instance variable to nil before calling
            # the parent class initializer. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              @deserializers = nil
              super
            end

            # Allows for setting all the deserializers with standard defaults
            # @param payload [Object] Deserializer for the message payload
            # @param key [Object] deserializer for the message key
            # @param headers [Object] deserializer for the message headers
            def deserializers(payload: UNSET, key: UNSET, headers: UNSET)
              @deserializers ||= Config.new(
                active: true,
                payload: UNSET.equal?(payload) ? Karafka::Deserializers::Payload.new : payload,
                key: UNSET.equal?(key) ? Karafka::Deserializers::Key.new : key,
                headers: UNSET.equal?(headers) ? Karafka::Deserializers::Headers.new : headers
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
end
