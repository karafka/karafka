# frozen_string_literal: true

setup_karafka do |config|
  config.kafka[:'compression.codec'] = 'gzip'
  config.kafka[:'compression.level'] = '12'
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 10
end
