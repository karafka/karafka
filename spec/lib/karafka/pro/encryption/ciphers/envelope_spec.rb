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

RSpec.describe_current do
  subject(:cipher) { described_class.new }

  before do
    allow(Karafka::App.config.encryption).to receive_messages(
      public_key: fixture_file("rsa/public_key_1.pem"),
      private_keys: { "1" => fixture_file("rsa/private_key_1.pem") }
    )
  end

  describe "#encrypt and #decrypt" do
    it "encrypts and decrypts payloads far beyond the RSA key capacity" do
      content = "a" * 100_000

      expect(cipher.decrypt("1", cipher.encrypt(content))).to eq(content)
    end

    it "handles empty payloads" do
      expect(cipher.decrypt("1", cipher.encrypt(""))).to eq("")
    end

    it "handles binary payloads" do
      content = Random.bytes(10_000)

      expect(cipher.decrypt("1", cipher.encrypt(content))).to eq(content)
    end

    it "produces a different envelope for the same content (fresh AES key each time)" do
      content = "same content"

      expect(cipher.encrypt(content)).not_to eq(cipher.encrypt(content))
    end
  end

  describe "corruption and forgery handling" do
    it "detects ciphertext tampering via the GCM auth tag" do
      envelope = cipher.encrypt("sensitive").b
      envelope.setbyte(-1, envelope.getbyte(-1) ^ 1)

      expect { cipher.decrypt("1", envelope) }.to raise_error(OpenSSL::Cipher::CipherError)
    end

    it "detects iv tampering (inherent to GCM, as the tag depends on the iv)" do
      envelope = cipher.encrypt("sensitive").b
      # Last iv byte, computed from the front of the layout:
      # [1B version][wrapped key (modulus size)][12B iv]...
      modulus_size = OpenSSL::PKey::RSA.new(fixture_file("rsa/public_key_1.pem")).n.num_bytes
      iv_position = 1 + modulus_size + 12 - 1
      envelope.setbyte(iv_position, envelope.getbyte(iv_position) ^ 1)

      expect { cipher.decrypt("1", envelope) }.to raise_error(OpenSSL::Cipher::CipherError)
    end

    it "authenticates the header via AAD (re-wrap of the same key is rejected)" do
      # The only header mutation that survives every other guard: the very same AES key
      # re-wrapped with the public key (OAEP is randomized, so different bytes, same key).
      # Version check passes, OAEP unwraps fine, key size, iv and tag are all valid - without
      # the AAD over the header this forgery would decrypt successfully
      envelope = cipher.encrypt("sensitive").b
      modulus_size = OpenSSL::PKey::RSA.new(fixture_file("rsa/public_key_1.pem")).n.num_bytes

      oaep = { rsa_padding_mode: "oaep", rsa_oaep_md: "sha256", rsa_mgf1_md: "sha256" }
      private_key = OpenSSL::PKey::RSA.new(fixture_file("rsa/private_key_1.pem"))
      aes_key = private_key.decrypt(envelope[1, modulus_size], oaep)

      public_key = OpenSSL::PKey::RSA.new(fixture_file("rsa/public_key_1.pem"))
      forged = envelope.dup
      forged[1, modulus_size] = public_key.encrypt(aes_key, oaep)

      expect(forged).not_to eq(envelope)
      expect { cipher.decrypt("1", forged) }.to raise_error(OpenSSL::Cipher::CipherError)
    end

    it "rejects truncated envelopes within the OpenSSL error family" do
      expect { cipher.decrypt("1", "") }
        .to raise_error(OpenSSL::PKey::RSAError, /corrupted or truncated/)

      expect { cipher.decrypt("1", "\x01short") }
        .to raise_error(OpenSSL::PKey::RSAError, /corrupted or truncated/)

      truncated = cipher.encrypt("sensitive").b[0..-30]

      expect { cipher.decrypt("1", truncated) }.to raise_error(OpenSSL::PKey::RSAError)
    end

    it "rejects unknown envelope format versions" do
      envelope = cipher.encrypt("sensitive").b
      envelope.setbyte(0, 0x02)

      expect { cipher.decrypt("1", envelope) }
        .to raise_error(OpenSSL::PKey::RSAError, /unsupported envelope version/)
    end

    it "reports unknown versions also for payloads shorter than the current layout" do
      # Version is checked before the full length so envelopes of future, differently-sized
      # layouts surface as unsupported to older consumers, not as corrupted
      expect { cipher.decrypt("1", "\x02") }
        .to raise_error(OpenSSL::PKey::RSAError, /unsupported envelope version/)
    end

    it "rejects forged envelopes wrapping a wrong-size AES key within the OpenSSL family" do
      # Anyone holding the (distributed) public key can wrap data of arbitrary length. Such
      # a forge must not escape as an ArgumentError from the AES key assignment
      public_key = OpenSSL::PKey::RSA.new(fixture_file("rsa/public_key_1.pem"))
      wrapped = public_key.encrypt(
        "k" * 16,
        rsa_padding_mode: "oaep", rsa_oaep_md: "sha256", rsa_mgf1_md: "sha256"
      )
      forged = "\x01".b + wrapped + ("\x00".b * 12) + ("\x00".b * 16)

      expect { cipher.decrypt("1", forged) }
        .to raise_error(OpenSSL::PKey::RSAError, /invalid envelope key size/)
    end

    it "fails reliably on a non-matching private key (OAEP unwrapping)" do
      allow(Karafka::App.config.encryption).to receive(:private_keys).and_return(
        "1" => fixture_file("rsa/private_key_2.pem")
      )

      envelope = cipher.encrypt("sensitive")

      expect { cipher.decrypt("1", envelope) }.to raise_error(OpenSSL::PKey::PKeyError)
    end
  end
end
