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
  subject(:cipher) { described_class.new }

  before do
    allow(Karafka::App.config.encryption).to receive_messages(
      public_key: fixture_file('rsa/public_key_1.pem'),
      private_keys: { '1' => fixture_file('rsa/private_key_1.pem') }
    )
  end

  describe '#encrypt and #decrypt' do
    let(:content) { 'this is a message' }

    context 'when using correct keys' do
      it 'expect to be able to descrypt and encrypt' do
        expect(cipher.decrypt('1', cipher.encrypt(content))).to eq(content)
      end
    end

    context 'when trying to use non-existing key' do
      let(:expected_error) { Karafka::Pro::Encryption::Errors::PrivateKeyNotFoundError }

      it 'expect to raise error' do
        expect { cipher.decrypt('2', content) }.to raise_error(expected_error)
      end
    end
  end
end
