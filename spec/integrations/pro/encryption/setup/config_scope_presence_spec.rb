# frozen_string_literal: true

# When using correct public and private keys, there should be no issues.

PUBLIC_KEY = <<~KEY
  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAryQICCl6NZ5gDKrnSztO
  3Hy8PEUcuyvg/ikC+VcIo2SFFSf18a3IMYldIugqqqZCs4/4uVW3sbdLs/6PfgdX
  7O9D22ZiFWHPYA2k2N744MNiCD1UE+tJyllUhSblK48bn+v1oZHCM0nYQ2NqUkvS
  j+hwUU3RiWl7x3D2s9wSdNt7XUtW05a/FXehsPSiJfKvHJJnGOX0BgTvkLnkAOTd
  OrUZ/wK69Dzu4IvrN4vs9Nes8vbwPa/ddZEzGR0cQMt0JBkhk9kU/qwqUseP1QRJ
  5I1jR4g8aYPL/ke9K35PxZWuDp3U0UPAZ3PjFAh+5T+fc7gzCs9dPzSHloruU+gl
  FQIDAQAB
  -----END PUBLIC KEY-----
KEY

PRIVATE_KEYS = {
  '1' => <<~KEY
    -----BEGIN RSA PRIVATE KEY-----
    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
    -----END RSA PRIVATE KEY-----
  KEY
}.freeze

setup_karafka do |config|
  config.encryption.active = true
  config.encryption.public_key = PUBLIC_KEY
  config.encryption.private_keys = PRIVATE_KEYS
end

# It is expected to use correct encryption aware parser
parser = ::Karafka::Pro::Encryption::Messages::Parser
assert Karafka::App.config.internal.messages.parser.is_a?(parser)
