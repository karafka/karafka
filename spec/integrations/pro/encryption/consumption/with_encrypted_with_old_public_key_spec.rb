# frozen_string_literal: true

# When using old public key to produce messages but this key is one of the supported, despite
# having new version, the message should be decrypted easily

PUBLIC_KEY = fixture_file('rsa/public_key_1.pem')

PRIVATE_KEYS = {
  '1' => fixture_file('rsa/private_key_1.pem'),
  '2' => fixture_file('rsa/private_key_2.pem')
}.freeze

setup_karafka do |config|
  config.encryption.active = true
  config.encryption.version = '2'
  config.encryption.public_key = PUBLIC_KEY
  config.encryption.private_keys = PRIVATE_KEYS
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

# Simulate using old version by changing version just for production
::Karafka::App.config.encryption.version = '1'

elements = DT.uuids(10)
produce_many(DT.topic, elements)

::Karafka::App.config.encryption.version = '2'

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal elements, DT[0]
assert_equal 1, DT.data.size
