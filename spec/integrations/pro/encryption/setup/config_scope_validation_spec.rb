# frozen_string_literal: true

# When providing invalid config details for encryption, validation should kick in.

PUBLIC_KEY = 'def not a public key'
PRIVATE_KEYS = { '1' => 'def not a private key' }.freeze

guarded = false
error = nil

begin
  setup_karafka do |config|
    config.encryption.active = true
    config.encryption.public_key = PUBLIC_KEY
    config.encryption.private_keys = PRIVATE_KEYS
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  guarded = true
  error = e
end

assert guarded

assert_equal error.message, { 'encryption.public_key': 'is not a valid public RSA key' }.to_s
