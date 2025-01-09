# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Encryption
      # Setup and config related encryption components
      module Setup
        # Config for encryption
        class Config
          extend ::Karafka::Core::Configurable

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
