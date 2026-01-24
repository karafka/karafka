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
  subject(:parsing) { described_class.new.call(message) }

  let(:message) { build(:messages_message, raw_payload: raw_payload, metadata: metadata) }
  let(:raw_payload) { { test: 1 }.to_json }
  let(:metadata) { build(:messages_metadata, raw_headers: headers) }
  let(:headers) { {} }

  context 'when encryption is not active' do
    it 'expect to run deserializer' do
      expect(parsing).to eq('test' => 1)
    end
  end

  context 'when encryption is active' do
    before { allow(Karafka::App.config.encryption).to receive(:active).and_return(true) }

    context 'when encryption is active but message without encryption' do
      it 'expect to run deserializer without anything else' do
        expect(parsing).to eq('test' => 1)
      end
    end

    context 'when encryption is active and message with valid encryption' do
      let(:headers) { { 'encryption' => '1' } }

      let(:raw_payload) do
        Karafka::App.config.encryption.cipher.encrypt({ 'test' => 1 }.to_json)
      end

      before do
        allow(Karafka::App.config.encryption).to receive_messages(
          public_key: fixture_file('rsa/public_key_1.pem'),
          private_keys: { '1' => fixture_file('rsa/private_key_1.pem') }
        )
      end

      it 'expect to decrypt it and then run deserializer' do
        expect(parsing).to eq('test' => 1)
      end
    end

    context 'when encryption is active but message with not matching encryption version' do
      let(:headers) { { 'encryption' => 'na' } }
      let(:expected_error) { Karafka::Pro::Encryption::Errors::PrivateKeyNotFoundError }

      it 'expect to raise an error' do
        expect { parsing }.to raise_error(expected_error)
      end
    end

    context 'when encrypted message does not match fingerprint but fingerprinting is off' do
      let(:headers) { { 'encryption' => '1', 'encryption_fingerprint' => rand.to_s } }

      let(:raw_payload) do
        Karafka::App.config.encryption.cipher.encrypt({ 'test' => 1 }.to_json)
      end

      before do
        allow(Karafka::App.config.encryption).to receive_messages(
          public_key: fixture_file('rsa/public_key_1.pem'),
          private_keys: { '1' => fixture_file('rsa/private_key_1.pem') }
        )
      end

      it 'expect to decrypt it and then run deserializer' do
        expect(parsing).to eq('test' => 1)
      end
    end

    context 'when encrypted message has no fingerprint but fingerprinting is on' do
      let(:headers) { { 'encryption' => '1' } }

      let(:raw_payload) do
        Karafka::App.config.encryption.cipher.encrypt({ 'test' => 1 }.to_json)
      end

      before do
        allow(Karafka::App.config.encryption).to receive_messages(
          public_key: fixture_file('rsa/public_key_1.pem'),
          fingerprinter: Digest::SHA256,
          private_keys: { '1' => fixture_file('rsa/private_key_1.pem') }
        )
      end

      it 'expect to decrypt it and then run deserializer' do
        expect(parsing).to eq('test' => 1)
      end
    end

    context 'when encrypted message has fingerprint, fingerprinting is on and invalid' do
      let(:headers) { { 'encryption' => '1', 'encryption_fingerprint' => rand.to_s } }

      let(:raw_payload) do
        Karafka::App.config.encryption.cipher.encrypt({ 'test' => 1 }.to_json)
      end

      let(:expected_error) do
        Karafka::Pro::Encryption::Errors::FingerprintVerificationError
      end

      before do
        allow(Karafka::App.config.encryption).to receive_messages(
          public_key: fixture_file('rsa/public_key_1.pem'),
          fingerprinter: Digest::MD5,
          private_keys: { '1' => fixture_file('rsa/private_key_1.pem') }
        )
      end

      it 'expect to decrypt and fail verification' do
        expect { parsing }.to raise_error(expected_error)
      end
    end

    context 'when encrypted message has fingerprint, fingerprinting is on and valid' do
      let(:headers) do
        {
          'encryption' => '1',
          'encryption_fingerprint' => Digest::MD5.hexdigest({ 'test' => 1 }.to_json)
        }
      end

      let(:raw_payload) do
        Karafka::App.config.encryption.cipher.encrypt({ 'test' => 1 }.to_json)
      end

      let(:expected_error) do
        Karafka::Pro::Encryption::Errors::FingerprintVerificationError
      end

      before do
        allow(Karafka::App.config.encryption).to receive_messages(
          public_key: fixture_file('rsa/public_key_1.pem'),
          fingerprinter: Digest::MD5,
          private_keys: { '1' => fixture_file('rsa/private_key_1.pem') }
        )
      end

      it 'expect to decrypt it and then run deserializer' do
        expect(parsing).to eq('test' => 1)
      end
    end
  end
end
