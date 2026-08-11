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
        # Hybrid cipher where each payload is encrypted with a one-time AES-256-GCM key and
        # only that key is RSA-wrapped (OAEP padding). Handles payloads of any size.
        #
        # The GCM auth tag covers the whole envelope (header included), so corruption and
        # truncation are detected reliably. Note this is corruption detection, not
        # authenticity: the RSA public key is distributed to all producers, so any of its
        # holders can construct a valid envelope.
        class Envelope < Base
          # Envelope binary format:
          #
          #   [1B format version][RSA-wrapped AES key (modulus size)][12B iv][16B tag][ciphertext]
          #
          # The wrapped key needs no size prefix as OAEP output is always exactly the modulus
          # size of the wrapping key. The version byte allows introducing new envelope layouts
          # (different AEAD, compression, etc.) without falling back to length arithmetic.
          VERSION = "\x01".b.freeze

          # Number of bytes of the leading format version marker
          VERSION_BYTES = 1

          # AES cipher used for the envelope payload encryption
          AES = "aes-256-gcm"

          # Number of bytes of the AES key wrapped inside the envelope. Derived from the
          # cipher so a future AES change cannot silently break the invariant
          KEY_BYTES = OpenSSL::Cipher.new(AES).key_len

          # Number of bytes of the AES-GCM initialization vector, derived like the key size
          IV_BYTES = OpenSSL::Cipher.new(AES).iv_len

          # Number of bytes of the AES-GCM authentication tag. This is a choice (GCM supports
          # shorter tags), not a cipher-derived property - 16 is the full, recommended size
          TAG_BYTES = 16

          # OAEP options for the AES key wrapping. SHA-256 for both MGF1 and the label hash -
          # OAEP does not lean on collision resistance, but the SHA-1 default draws flags from
          # scanners and compliance checklists
          OAEP_OPTIONS = {
            rsa_padding_mode: "oaep",
            rsa_oaep_md: "sha256",
            rsa_mgf1_md: "sha256"
          }.freeze

          private_constant :VERSION, :VERSION_BYTES, :AES, :KEY_BYTES, :IV_BYTES, :TAG_BYTES,
            :OAEP_OPTIONS

          # Encrypts content with a one-time AES-256-GCM key and RSA-wraps that key using OAEP
          # padding. Unlike PKCS1 v1.5, OAEP unwrapping with a non-matching key fails reliably
          # instead of occasionally yielding garbage. The GCM tag additionally authenticates
          # the whole envelope header, so any bit flip in the version byte, wrapped key or iv
          # is detected, not only ciphertext corruption.
          #
          # @param content [String] content to encrypt
          # @return [String] binary envelope (see {VERSION} for the format)
          def encrypt(content)
            aes = OpenSSL::Cipher.new(AES).encrypt
            aes_key = aes.random_key
            iv = aes.random_iv

            wrapped_key = public_pem.encrypt(aes_key, OAEP_OPTIONS)

            header = VERSION + wrapped_key + iv
            aes.auth_data = header

            # `Cipher#update` rejects empty input on openssl gem < 3.1 (`data must not be
            # empty`), so empty payloads go straight to `#final`
            ciphertext = content.empty? ? aes.final : aes.update(content) + aes.final

            header + aes.auth_tag(TAG_BYTES) + ciphertext
          end

          # Decrypts an envelope produced by {#encrypt}
          # @param version [String] encryption version
          # @param content [String] binary envelope
          # @return [String] decrypted content
          # @note All failure paths stay within the `OpenSSL::PKey` error family: the explicit
          #   guards raise `RSAError`, while an OAEP unwrap failure (e.g. non-matching private
          #   key) surfaces from the EVP API as its parent `PKeyError`
          def decrypt(version, content)
            content = content.b

            if content.bytesize < VERSION_BYTES
              raise(OpenSSL::PKey::RSAError, "corrupted or truncated envelope")
            end

            # Version goes next so future layouts of different sizes are reported as
            # unsupported to older consumers instead of as corrupted
            if content[0, VERSION_BYTES] != VERSION
              raise(OpenSSL::PKey::RSAError, "unsupported envelope version")
            end

            pem = private_pem(version)
            wrapped_size = pem.n.num_bytes
            header_size = VERSION_BYTES + wrapped_size + IV_BYTES
            min_size = header_size + TAG_BYTES

            if content.bytesize < min_size
              raise(OpenSSL::PKey::RSAError, "corrupted or truncated envelope")
            end

            wrapped_key = content[VERSION_BYTES, wrapped_size]
            iv = content[VERSION_BYTES + wrapped_size, IV_BYTES]
            tag = content[header_size, TAG_BYTES]
            ciphertext = content[min_size..]

            aes_key = pem.decrypt(wrapped_key, OAEP_OPTIONS)

            # OAEP unwrapping of a foreign envelope fails reliably, but anyone holding the
            # public key can wrap a string of arbitrary length. Without this guard such input
            # would surface as an ArgumentError from the AES key assignment, escaping the
            # OpenSSL error family this method otherwise normalizes to
            unless aes_key.bytesize == KEY_BYTES
              raise(OpenSSL::PKey::RSAError, "invalid envelope key size")
            end

            aes = OpenSSL::Cipher.new(AES).decrypt
            aes.key = aes_key
            aes.iv = iv
            aes.auth_tag = tag
            aes.auth_data = content[0, header_size]

            # Same empty-input guard as on the encryption side; `#final` still runs and thus
            # still verifies the auth tag for empty payloads
            ciphertext.empty? ? aes.final : aes.update(ciphertext) + aes.final
          end
        end
      end
    end
  end
end
