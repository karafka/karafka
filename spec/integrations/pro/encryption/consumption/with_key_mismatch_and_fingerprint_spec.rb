# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When producing with version that is not supported in reading, it should raise an error

PUBLIC_KEY = fixture_file('rsa/public_key_1.pem')

PRIVATE_KEYS = {
  '1' => fixture_file('rsa/private_key_2.pem')
}.freeze

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.encryption.active = true
  config.encryption.version = '1'
  config.encryption.public_key = PUBLIC_KEY
  config.encryption.private_keys = PRIVATE_KEYS
  config.encryption.fingerprinter = Digest::MD5
end

Karafka.monitor.subscribe('error.occurred') do |event|
  DT[:errors] << event
end

module Karafka
  module Pro
    module Encryption
      class Cipher
        # Fake invalid description.
        # We mock it because depending on the libssl version it may or may not raise and error
        def decrypt(_version, _content)
          rand.to_s
        end
      end
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.payload
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializer ->(message) { message.raw_payload.to_s }
  end
end

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  !DT[:errors].empty? || DT[0].size >= 10
end

expected_error = Karafka::Pro::Encryption::Errors::FingerprintVerificationError
assert DT[:errors].first.payload[:error].is_a?(expected_error)
