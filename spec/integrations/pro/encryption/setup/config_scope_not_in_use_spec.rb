# frozen_string_literal: true

# When encryption is not enabled, we should not inject or configure its components

PUBLIC_KEY = 'def not a public key'
PRIVATE_KEYS = { '1' => 'def not a private key' }.freeze

setup_karafka do |config|
  config.encryption.active = false
  config.encryption.public_key = PUBLIC_KEY
  config.encryption.private_keys = PRIVATE_KEYS
end

parser = ::Karafka::Messages::Parser
assert Karafka::App.config.internal.messages.parser.is_a?(parser)
