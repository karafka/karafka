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
          # @param message [::Karafka::Messages::Message]
          # @return [Object] deserialized payload
          def call(message)
            if active? && message.headers.key?('encryption')
              # Decrypt raw payload so it can be handled by the default parser logic
              message.raw_payload = cipher.decrypt(
                message.headers['encryption'],
                message.raw_payload
              )
            end

            super(message)
          end

          private

          # @return [::Karafka::Pro::Encryption::Cipher]
          def cipher
            @cipher ||= ::Karafka::App.config.encryption.cipher
          end

          # @return [Boolean] is encryption active
          def active?
            return @active unless @active.nil?

            @active = ::Karafka::App.config.encryption.active

            @active
          end
        end
      end
    end
  end
end
