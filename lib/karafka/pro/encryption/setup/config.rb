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
      # Setup and config related encryption components
      module Setup
        # Config for encryption
        class Config
          extend Karafka::Core::Configurable

          # Should this feature be in use
          setting(:active, default: false)

          # Supporting versions allows us to be able to rotate private and public keys in case
          # we would need this. We can increase the version, rotate and Karafka when decrypting
          # will figure out proper private key based on the version
          setting(:version, default: "1")

          # We always support one public key for producing messages
          # Public key needs to be always present even if we do not plan to produce messages from
          # a Karafka process. This is because of the web-ui and potentially other cases like this
          setting(:public_key, default: "")

          # Private keys in pem format, where the key is the version and value is the key.
          # This allows us to support key rotation
          setting(:private_keys, default: {})

          # Encryption mode used when producing messages:
          #
          # - `:direct` (default) - payload is RSA-encrypted directly, which limits it to the
          #   RSA key capacity (key size minus padding, ~245 bytes for 2048-bit keys). Default
          #   for backwards compatibility with already running deployments. The default will
          #   switch to `:envelope` in a future release (with prior notice); decryption of the
          #   `:direct` format is never planned for removal, as data at rest never expires.
          # - `:envelope` - payload is encrypted with a one-time AES-256-GCM key and only that
          #   key is RSA-wrapped, so payloads of any size are supported and the GCM auth tag
          #   detects corruption and truncation. Note this is not authenticity: the public key
          #   is distributed to all producers, so any of its holders can build a valid envelope
          #
          # Decryption always supports both formats regardless of this setting. Since processes
          # older than the version that introduced this setting cannot decrypt envelope
          # payloads, when enabling `:envelope` upgrade all consuming processes first and only
          # then switch producers to the envelope mode.
          #
          # The envelope openssl gem requirement (>= 3.0) is verified during setup. Flipping
          # this setting to `:envelope` at runtime on an unsupported openssl bypasses that
          # friendly boot error and fails on first use instead.
          setting(:mode, default: :direct)

          # Cipher used to encrypt and decrypt data
          setting(:cipher, default: Encryption::Cipher.new)

          # When set to any digest that responds to `#hexdigest` will compute checksum of the
          # message payload for post-description integrity verification. It will include a
          # fingerprint in headers
          setting(:fingerprinter, default: false)

          configure
        end
      end
    end
  end
end
