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
    module Encryption
      # Encryption related messages components
      module Messages
        # Middleware for WaterDrop. It automatically encrypts messages payload.
        # It is injected only if encryption is enabled.
        # It also fingerprints the payload for verification if fingerprinting was enabled
        class Middleware
          include Helpers::ConfigImporter.new(
            cipher: %i[encryption cipher],
            version: %i[encryption version],
            fingerprinter: %i[encryption fingerprinter]
          )

          # @param message [Hash] WaterDrop message hash
          # @return [Hash] hash with encrypted payload and encryption version indicator
          def call(message)
            payload = message[:payload]

            message[:headers] ||= {}
            message[:headers]['encryption'] = version
            message[:payload] = cipher.encrypt(payload)

            return message unless fingerprinter

            message[:headers]['encryption_fingerprint'] = fingerprinter.hexdigest(payload)

            message
          end
        end
      end
    end
  end
end
