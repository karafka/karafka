# frozen_string_literal: true

# Karafka should work correctly when we configure it only to have public key and for messages
# producing only. Decryption will not be possible.

PUBLIC_KEY = fixture_file('rsa/public_key_1.pem')

setup_karafka do |config|
  config.encryption.active = true
  config.encryption.public_key = PUBLIC_KEY
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
      DT[:encryption] << message.headers['encryption']
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 10
end

# There should be no raw info available
chunk = elements.first.split('-').first
assert(DT[0].none? { |payload| payload.include?(chunk) })

# Correct encryption version headers should be present
assert_equal %w[1], DT[:encryption].uniq
