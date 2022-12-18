# frozen_string_literal: true

# When using public key to publish and a key that is not matching on version, we should get OpenSSL
# error

PUBLIC_KEY = fixture_file('rsa/public_key_1.pem')

PRIVATE_KEYS = {
  '1' => fixture_file('rsa/private_key_2.pem')
}.freeze

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.encryption.active = true
  config.encryption.version = '1'
  config.encryption.public_key = PUBLIC_KEY
  config.encryption.private_keys = PRIVATE_KEYS
end

Karafka.monitor.subscribe('error.occurred') do |event|
  DT[:errors] << event
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
  !DT[:errors].empty?
end

assert DT[:errors].first.payload[:error].is_a?(OpenSSL::PKey::PKeyError)
