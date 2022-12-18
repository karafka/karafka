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

          configure
        end
      end
    end
  end
end
