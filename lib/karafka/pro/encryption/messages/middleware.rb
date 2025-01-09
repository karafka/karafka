# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
