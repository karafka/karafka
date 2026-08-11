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
    let(:content) { "this is a message" }

    context "when using correct keys" do
      it "expect to be able to descrypt and encrypt" do
        expect(cipher.decrypt("1", cipher.encrypt(content))).to eq(content)
      end
    end

    context "when trying to use non-existing key" do
      let(:expected_error) { Karafka::Pro::Encryption::Errors::PrivateKeyNotFoundError }

      it "expect to raise error" do
        expect { cipher.decrypt("2", content) }.to raise_error(expected_error)
      end
    end
  end

  describe "mode dispatch on encryption" do
    let(:modulus_size) do
      OpenSSL::PKey::RSA.new(fixture_file("rsa/public_key_1.pem")).n.num_bytes
    end

    it "produces the direct RSA format in the default direct mode" do
      expect(cipher.encrypt("content").bytesize).to eq(modulus_size)
    end

    context "when envelope mode is configured" do
      before do
        allow(Karafka::App.config.encryption).to receive(:mode).and_return(:envelope)
      end

      it "produces the envelope format" do
        expect(cipher.encrypt("content").bytesize).to be > modulus_size
      end

      it "supports payloads beyond the direct RSA capacity" do
        content = "a" * 10_000

        expect(cipher.decrypt("1", cipher.encrypt(content))).to eq(content)
      end
    end
  end

  describe "format routing on decryption" do
    it "decrypts direct format payloads while in envelope mode" do
      direct = cipher.encrypt("legacy at rest")

      allow(Karafka::App.config.encryption).to receive(:mode).and_return(:envelope)

      expect(cipher.decrypt("1", direct)).to eq("legacy at rest")
    end

    it "decrypts envelope format payloads while in direct mode" do
      allow(Karafka::App.config.encryption).to receive(:mode).and_return(:envelope)
      envelope = cipher.encrypt("new format")
      allow(Karafka::App.config.encryption).to receive(:mode).and_return(:direct)

      expect(cipher.decrypt("1", envelope)).to eq("new format")
    end

    it "routes payloads of exactly the modulus size to the direct RSA path" do
      # Inherent blind spot of the size heuristic: such input cannot be told apart from a
      # direct ciphertext. Depending on the exact bytes it either raises an RSA error or -
      # when the PKCS1 v1.5 padding coincidentally validates - yields garbage. It must never
      # produce the envelope diagnostics nor the original plaintext
      allow(Karafka::App.config.encryption).to receive(:mode).and_return(:envelope)
      modulus_size = OpenSSL::PKey::RSA.new(fixture_file("rsa/public_key_1.pem")).n.num_bytes
      truncated = cipher.encrypt("sensitive").b[0, modulus_size]

      begin
        expect(cipher.decrypt("1", truncated)).not_to eq("sensitive")
      rescue OpenSSL::PKey::PKeyError => e
        expect(e.message).not_to match(/corrupted|unsupported/)
      end
    end
  end
end
