# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
