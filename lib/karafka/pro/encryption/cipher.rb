# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Encryption
      # Cipher for encrypting and decrypting data
      class Cipher
        include Helpers::ConfigImporter.new(
          encryption: %i[encryption]
        )

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
          @public_pem ||= ::OpenSSL::PKey::RSA.new(encryption.public_key)
        end

        # @param version [String] version for which we want to get the rsa key
        # @return [::OpenSSL::PKey::RSA] rsa private key
        def private_pem(version)
          return @private_pems[version] if @private_pems.key?(version)

          key_string = encryption.private_keys[version]
          key_string || raise(Errors::PrivateKeyNotFoundError, version)

          @private_pems[version] = ::OpenSSL::PKey::RSA.new(key_string)
        end
      end
    end
  end
end
