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

  let(:direct_limit) do
    OpenSSL::PKey::RSA.new(fixture_file("rsa/public_key_1.pem")).n.num_bytes - 11
  end

  describe "#encrypt and #decrypt" do
    it "round-trips payloads up to the RSA PKCS1 capacity" do
      content = "a" * direct_limit

      expect(cipher.decrypt("1", cipher.encrypt(content))).to eq(content)
    end

    it "cannot encrypt payloads exceeding the RSA PKCS1 capacity" do
      # Class-only assertion: the message and the exact class (RSAError vs PKeyError) differ
      # across OpenSSL 1.1/3.x builds
      expect { cipher.encrypt("a" * (direct_limit + 1)) }
        .to raise_error(OpenSSL::PKey::PKeyError)
    end
  end

  describe "#owns?" do
    it "recognizes content of exactly the key modulus size as its own format" do
      expect(cipher.owns?("1", cipher.encrypt("content"))).to be(true)
    end

    it "does not claim content of any other size" do
      expect(cipher.owns?("1", "too short")).to be(false)
      expect(cipher.owns?("1", "x" * 1_000)).to be(false)
    end

    it "raises on an unknown key version like any other key resolution" do
      expect { cipher.owns?("2", "x") }
        .to raise_error(Karafka::Pro::Encryption::Errors::PrivateKeyNotFoundError)
    end
  end
end
