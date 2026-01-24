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
          setting(:version, default: '1')

          # We always support one public key for producing messages
          # Public key needs to be always present even if we do not plan to produce messages from
          # a Karafka process. This is because of the web-ui and potentially other cases like this
          setting(:public_key, default: '')

          # Private keys in pem format, where the key is the version and value is the key.
          # This allows us to support key rotation
          setting(:private_keys, default: {})

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
