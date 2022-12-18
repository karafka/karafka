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
        class Middleware
          # @param message [Hash] WaterDrop message hash
          # @return [Hash] hash with encrypted payload and encryption version indicator
          def call(message)
            message[:headers] ||= {}
            message[:headers]['encryption'] = version
            message[:payload] = cipher.encrypt(message[:payload])
            message
          end

          private

          # @return [::Karafka::Pro::Encryption::Cipher]
          def cipher
            @cipher ||= ::Karafka::App.config.encryption.cipher
          end

          # @return [String] encryption version
          def version
            @version ||= ::Karafka::App.config.encryption.version
          end
        end
      end
    end
  end
end
