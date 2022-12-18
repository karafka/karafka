# frozen_string_literal: true

RSpec.describe_current do
  subject(:parsing) { described_class.new.call(message) }

  let(:message) { build(:messages_message, raw_payload: raw_payload, metadata: metadata) }
  let(:raw_payload) { { test: 1 }.to_json }
  let(:metadata) { build(:messages_metadata, headers: headers) }
  let(:headers) { {} }

  context 'when encryption is not active' do
    it 'expect to run deserializer' do
      expect(parsing).to eq('test' => 1)
    end
  end

  context 'when encryption is active' do
    before { allow(::Karafka::App.config.encryption).to receive(:active).and_return(true) }

    context 'when encryption is active but message without encryption' do
      it 'expect to run deserializer without anything else' do
        expect(parsing).to eq('test' => 1)
      end
    end

    context 'when encryption is active and message with valid encryption' do
      let(:headers) { { 'encryption' => '1' } }

      let(:raw_payload) do
        ::Karafka::App.config.encryption.cipher.encrypt({ 'test' => 1 }.to_json)
      end

      before do
        allow(::Karafka::App.config.encryption)
          .to receive(:public_key)
          .and_return(fixture_file('rsa/public_key_1.pem'))

        allow(::Karafka::App.config.encryption)
          .to receive(:private_keys)
          .and_return('1' => fixture_file('rsa/private_key_1.pem'))
      end

      it 'expect to decrypt it and then run deserializer' do
        expect(parsing).to eq('test' => 1)
      end
    end

    context 'when encryption is active but message with not matching encryption version' do
      let(:headers) { { 'encryption' => 'na' } }

      it 'expect to raise an error' do
        expect { parsing }.to raise_error(Karafka::Pro::Encryption::Errors::PrivateKeyNotFound)
      end
    end
  end
end
