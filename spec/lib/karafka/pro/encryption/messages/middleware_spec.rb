# frozen_string_literal: true

RSpec.describe_current do
  subject(:middleware) { described_class.new.call(message) }

  before do
    allow(::Karafka::App.config.encryption)
      .to receive(:public_key)
      .and_return(fixture_file('rsa/public_key_1.pem'))

    allow(::Karafka::App.config.encryption)
      .to receive(:private_keys)
      .and_return('1' => fixture_file('rsa/private_key_1.pem'))
  end

  let(:message) do
    {
      headers: {},
      payload: 'test message'
    }
  end

  it 'expect to encrypt the payload' do
    encrypted = middleware[:payload]

    expect(::Karafka::App.config.encryption.cipher.decrypt('1', encrypted)).to eq('test message')
  end

  it 'expect to add encryption version to headers' do
    expect { middleware }
      .to change { message[:headers] }
      .from({})
      .to('encryption' => '1')
  end
end
