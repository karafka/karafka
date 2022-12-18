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
      # Cipher for encrypting and decrypting data
      class Cipher
        def initialize
          @private_pems = {}
        end

        # Encrypts given string content with the public key
        # @param content [String]
        # @return [String]
        def encrypt(content)
          public_pem.public_encrypt(content)
        end

        # Decrypts provided content using `version` key
        # @param version [String] encryption version
        # @param content [String] encrypted content
        # @return [String] decrypted content
        def decrypt(version, content)
          private_pem(version).private_decrypt(content)
        end

        private

        # @return [::OpenSSL::PKey::RSA] rsa public key
        def public_pem
          @public_pem ||= ::OpenSSL::PKey::RSA.new(::Karafka::App.config.encryption.public_key)
        end

        # @param version [String] version for which we want to get the rsa key
        # @return [::OpenSSL::PKey::RSA] rsa private key
        def private_pem(version)
          return @private_pems[version] if @private_pems.key?(version)

          key_string = ::Karafka::App.config.encryption.private_keys[version]
          key_string || raise(Errors::PrivateKeyNotFound, version)

          @private_pems[version] = ::OpenSSL::PKey::RSA.new(key_string)
        end
      end
    end
  end
end
