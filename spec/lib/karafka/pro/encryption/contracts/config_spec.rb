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

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) do
    {
      encryption: {
        active: false,
        version: "1",
        public_key: "",
        private_keys: {},
        cipher: Karafka::Pro::Encryption::Cipher.new,
        fingerprinter: false
      }
    }
  end

  let(:encryption) { config[:encryption] }

  context "when config is valid" do
    it { expect(contract.call(config)).to be_success }
  end

  context "when active status is not a boolean" do
    before { encryption[:active] = "1" }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when version is not a string" do
    before { encryption[:version] = 1 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when public_key is not a string" do
    before { encryption[:public_key] = 1 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when private_keys is not a hash" do
    before { encryption[:private_keys] = [] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when public key is invalid but encryption is not active" do
    before { encryption[:public_key] = "not a key" }

    it { expect(contract.call(config)).to be_success }
  end

  context "when fingerprinter is provided" do
    context "when it does not respond to #hexdigest" do
      before { encryption[:fingerprinter] = Object }

      it { expect(contract.call(config)).not_to be_success }
    end

    context "when it does respond to #hexdigest" do
      before { encryption[:fingerprinter] = Digest::SHA256 }

      it { expect(contract.call(config)).to be_success }
    end
  end

  context "when encryption is enabled" do
    before { encryption[:active] = true }

    context "when public key is invalid and encryption is active" do
      before { encryption[:public_key] = "not a key" }

      it { expect(contract.call(config)).not_to be_success }
    end

    context "when public key is valid and encryption is active" do
      before { encryption[:public_key] = fixture_file("rsa/public_key_1.pem") }

      it { expect(contract.call(config)).to be_success }
    end

    context "when public key is present but is private and encryption is active" do
      before { encryption[:public_key] = fixture_file("rsa/private_key_1.pem") }

      it { expect(contract.call(config)).not_to be_success }
    end

    context "when private keys version key is not a string" do
      before do
        encryption[:public_key] = fixture_file("rsa/public_key_1.pem")
        encryption[:private_keys] = { 1 => "" }
      end

      it { expect(contract.call(config)).not_to be_success }
    end

    context "when private key is set but it is public" do
      before do
        encryption[:public_key] = fixture_file("rsa/public_key_1.pem")
        encryption[:private_keys] = { "1" => fixture_file("rsa/public_key_1.pem") }
      end

      it { expect(contract.call(config)).not_to be_success }
    end

    context "when private key is set and private" do
      before do
        encryption[:public_key] = fixture_file("rsa/public_key_1.pem")
        encryption[:private_keys] = { "1" => fixture_file("rsa/private_key_1.pem") }
      end

      it { expect(contract.call(config)).to be_success }
    end

    context "when private key is set but it is not a pem key" do
      before do
        encryption[:public_key] = fixture_file("rsa/public_key_1.pem")
        encryption[:private_keys] = { "1" => "not a key" }
      end

      it { expect(contract.call(config)).not_to be_success }
    end
  end
end
