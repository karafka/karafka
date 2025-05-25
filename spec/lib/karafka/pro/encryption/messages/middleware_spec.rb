# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:middleware) { described_class.new.call(message) }

  before do
    allow(::Karafka::App.config.encryption).to receive_messages(
      public_key: fixture_file('rsa/public_key_1.pem'),
      private_keys: { '1' => fixture_file('rsa/private_key_1.pem') }
    )
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

  context 'when custom fingerprinter is defined' do
    let(:expected) do
      <<~DIGEST.delete("\n")
        92bf445810db8cbd9802
        cd585fb76e08801b8202
        e923ee842be8179a97ee
        c4078d4cf45a3b3d5201
        1d0ca7bbfd9c2e2b
      DIGEST
    end

    before do
      allow(::Karafka::App.config.encryption)
        .to receive(:fingerprinter)
        .and_return(Digest::SHA384)
    end

    it 'expect to use it and create fingerprint header' do
      expect { middleware }
        .to change { message[:headers] }
        .from({})
        .to('encryption' => '1', 'encryption_fingerprint' => expected)
    end
  end
end
