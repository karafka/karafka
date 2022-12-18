# frozen_string_literal: true

RSpec.describe_current do
  subject(:cipher) { described_class.new }

  before do
    allow(::Karafka::App.config.encryption)
      .to receive(:public_key)
      .and_return(fixture_file('rsa/public_key_1.pem'))

    allow(::Karafka::App.config.encryption)
      .to receive(:private_keys)
      .and_return('1' => fixture_file('rsa/private_key_1.pem'))
  end

  describe '#encrypt and #decrypt' do
    let(:content) { 'this is a message' }

    context 'when using correct keys' do
      it 'expect to be able to descrypt and encrypt' do
        expect(cipher.decrypt('1', cipher.encrypt(content))).to eq(content)
      end
    end

    context 'when trying to use non-existing key' do
      let(:expected_error) { ::Karafka::Pro::Encryption::Errors::PrivateKeyNotFound }

      it 'expect to raise error' do
        expect { cipher.decrypt('2', content) }.to raise_error(expected_error)
      end
    end
  end
end
