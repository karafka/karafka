# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) do
    {
      encryption: {
        active: false,
        version: '1',
        public_key: '',
        private_keys: {},
        cipher: Karafka::Pro::Encryption::Cipher.new
      }
    }
  end

  let(:encryption) { config[:encryption] }

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }
  end

  context 'when active status is not a boolean' do
    before { encryption[:active] = '1' }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when version is not a string' do
    before { encryption[:version] = 1 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when public_key is not a string' do
    before { encryption[:public_key] = 1 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when private_keys is not a hash' do
    before { encryption[:private_keys] = [] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when public key is invalid but encryption is not active' do
    before { encryption[:public_key] = 'not a key' }

    it { expect(contract.call(config)).to be_success }
  end

  context 'when encryption is enabled' do
    before { encryption[:active] = true }

    context 'when public key is invalid and encryption is active' do
      before { encryption[:public_key] = 'not a key' }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when public key is valid and encryption is active' do
      before { encryption[:public_key] = fixture_file('rsa/public_key_1.pem') }

      it { expect(contract.call(config)).to be_success }
    end

    context 'when public key is present but is private and encryption is active' do
      before { encryption[:public_key] = fixture_file('rsa/private_key_1.pem') }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when private keys version key is not a string' do
      before do
        encryption[:public_key] = fixture_file('rsa/public_key_1.pem')
        encryption[:private_keys] = { 1 => '' }
      end

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when private key is set but it is public' do
      before do
        encryption[:public_key] = fixture_file('rsa/public_key_1.pem')
        encryption[:private_keys] = { '1' => fixture_file('rsa/public_key_1.pem') }
      end

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when private key is set and private' do
      before do
        encryption[:public_key] = fixture_file('rsa/public_key_1.pem')
        encryption[:private_keys] = { '1' => fixture_file('rsa/private_key_1.pem') }
      end

      it { expect(contract.call(config)).to be_success }
    end

    context 'when private key is set but it is not a pem key' do
      before do
        encryption[:public_key] = fixture_file('rsa/public_key_1.pem')
        encryption[:private_keys] = { '1' => 'not a key' }
      end

      it { expect(contract.call(config)).not_to be_success }
    end
  end
end
