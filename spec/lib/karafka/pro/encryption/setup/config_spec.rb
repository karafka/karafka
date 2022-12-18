# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) { described_class.config }

  it { expect(config.active).to eq(false) }
  it { expect(config.version).to eq('1') }
  it { expect(config.public_key).to eq('') }
  it { expect(config.private_keys).to eq({}) }
  it { expect(config.cipher).to be_a(::Karafka::Pro::Encryption::Cipher) }
end
