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

            return super(message) unless fingerprint

            message_fingerprint = fingerprinter.hexdigest(decrypted_payload)

            return super(message) if message_fingerprint == fingerprint

            raise(Errors::IntegrityVerificationError, message.to_s)
          end
        end
      end
    end
  end
end
