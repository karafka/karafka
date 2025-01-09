# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ScheduledMessages
      module Deserializers
        # States payload deserializer
        # We only deserialize states data and never anything else. Other payloads are the payloads
        # we are expected to proxy, thus there is no need to deserialize them in any context.
        # Their appropriate target topics should have expected deserializers
        class Payload
          # @param message [::Karafka::Messages::Message]
          # @return [Hash] deserialized data
          def call(message)
            ::JSON.parse(
              Zlib::Inflate.inflate(message.raw_payload),
              symbolize_names: true
            )
          end
        end
      end
    end
  end
end
