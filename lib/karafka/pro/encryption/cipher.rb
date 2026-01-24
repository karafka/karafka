# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module Encryption
      # Cipher for encrypting and decrypting data
      class Cipher
        include Helpers::ConfigImporter.new(
          encryption: %i[encryption]
        )

        # Initializes the cipher with empty private keys cache
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
          @public_pem ||= OpenSSL::PKey::RSA.new(encryption.public_key)
        end

        # @param version [String] version for which we want to get the rsa key
        # @return [::OpenSSL::PKey::RSA] rsa private key
        def private_pem(version)
          return @private_pems[version] if @private_pems.key?(version)

          key_string = encryption.private_keys[version]
          key_string || raise(Errors::PrivateKeyNotFoundError, version)

          @private_pems[version] = OpenSSL::PKey::RSA.new(key_string)
        end
      end
    end
  end
end
