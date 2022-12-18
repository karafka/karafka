# frozen_string_literal: true

# When using correct public and private keys, there should be no issues.

PUBLIC_KEY = fixture_file('rsa/public_key_1.pem')
PRIVATE_KEYS = { '1' => fixture_file('rsa/private_key_1.pem') }.freeze

setup_karafka do |config|
  config.encryption.active = true
  config.encryption.public_key = PUBLIC_KEY
  config.encryption.private_keys = PRIVATE_KEYS
end

# It is expected to use correct encryption aware parser
parser = ::Karafka::Pro::Encryption::Messages::Parser
assert Karafka::App.config.internal.messages.parser.is_a?(parser)
