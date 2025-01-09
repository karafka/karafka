# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Encryption
      module Messages
        # Pro parser that takes into consideration encryption usage
        # @note There may be a case where someone decides not to encrypt data and we start getting
        #   unencrypted payloads. That is why we always rely on message headers for encryption
        #   indication.
        class Parser < ::Karafka::Messages::Parser
          include Helpers::ConfigImporter.new(
            cipher: %i[encryption cipher],
            active: %i[encryption active],
            fingerprinter: %i[encryption fingerprinter]
          )

          # @param message [::Karafka::Messages::Message]
          # @return [Object] deserialized payload
          def call(message)
            headers = message.headers
            encryption = headers['encryption']
            fingerprint = headers['encryption_fingerprint']

            return super(message) unless active && encryption

            # Decrypt raw payload so it can be handled by the default parser logic
            decrypted_payload = cipher.decrypt(
              encryption,
              message.raw_payload
            )

            message.raw_payload = decrypted_payload

            return super(message) unless fingerprint && fingerprinter

            message_fingerprint = fingerprinter.hexdigest(decrypted_payload)

            return super(message) if message_fingerprint == fingerprint

            raise(Errors::FingerprintVerificationError, message.to_s)
          end
        end
      end
    end
  end
end
