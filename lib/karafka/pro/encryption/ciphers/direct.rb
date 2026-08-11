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
      module Ciphers
        # Legacy cipher where the payload is RSA-encrypted directly with PKCS1 v1.5 padding.
        #
        # RSA can only encrypt data smaller than the key size minus padding (e.g. ~245 bytes
        # for a 2048-bit key, ~501 bytes for a 4096-bit key), so it is unsuitable for larger
        # payloads and remains available only for backwards compatibility with data already
        # encrypted at rest and with fleets not yet fully upgraded.
        class Direct < Base
          # Encrypts given content with the public key
          # @param content [String]
          # @return [String] RSA ciphertext, always exactly the key modulus size
          def encrypt(content)
            public_pem.public_encrypt(content)
          end

          # Decrypts provided content using the `version` private key
          # @param version [String] encryption version
          # @param content [String] encrypted content
          # @return [String] decrypted content
          def decrypt(version, content)
            private_pem(version).private_decrypt(content)
          end

          # @param version [String] encryption version
          # @param content [String] encrypted content
          # @return [Boolean] true if the content matches this cipher's format. A valid direct
          #   RSA ciphertext is always exactly the key modulus size
          #
          # @note One inherent blind spot: an envelope truncated to exactly the modulus size is
          #   indistinguishable from a direct ciphertext. It surfaces as an RSA padding error
          #   or - when the PKCS1 v1.5 padding coincidentally validates - as garbage output,
          #   never as the envelope diagnostics. The legacy direct format carries no marker
          #   that could disambiguate this.
          def owns?(version, content)
            content.bytesize == private_pem(version).n.num_bytes
          end
        end
      end
    end
  end
end
