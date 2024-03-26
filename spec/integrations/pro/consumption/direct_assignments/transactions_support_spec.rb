# frozen_string_literal: true

# We should be able to assign what we want and mark offsets in a transaction

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    transaction do
      messages.each { |message| mark_as_consumed(message) }
      produce_async(topic: DT.topic, payload: '1')
    end

    DT[:done] = true

    sleep(2)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    assign(true)
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert fetch_next_offset >= 10
