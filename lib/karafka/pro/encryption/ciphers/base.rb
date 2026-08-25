# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module Encryption
      # Namespace for the cipher implementations behind the encryption modes
      module Ciphers
        # Base for the cipher implementations, providing shared access to the configured RSA
        # key material with per-version private key resolution
        class Base
          include Helpers::ConfigImporter.new(
            encryption: %i[encryption]
          )

          # Initializes the cipher with an empty private keys cache
          #
          # @note Each cipher instance holds its own tiny cache of parsed pem objects. With two
          #   cipher implementations composed by {Encryption::Cipher} this means the material
          #   is parsed at most twice per version, which we accept over introducing a shared
          #   keyring concept
          #
          # @note The caches are populated via {#warmup} during the single-threaded setup
          #   phase, so under normal operations runtime access is read-only. Should a key
          #   version appear only at runtime, the lazy population is idempotent and benign
          #   under MRI (worst case the same pem is parsed twice)
          def initialize
            @private_pems = {}
          end

          # Eagerly parses the given encryption config key material into the instance caches
          #
          # @param encryption_config [Karafka::Core::Configurable::Node] encryption config
          #   node. During setup it is the same node the lazy readers resolve at runtime,
          #   passed explicitly so this method does not silently couple to the global state
          def warmup(encryption_config)
            @public_pem ||= OpenSSL::PKey::RSA.new(encryption_config.public_key)

            encryption_config.private_keys.each do |version, key|
              @private_pems[version] ||= OpenSSL::PKey::RSA.new(key)
            end
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
end
