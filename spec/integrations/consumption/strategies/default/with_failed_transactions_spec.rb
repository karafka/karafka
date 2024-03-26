# frozen_string_literal: true

# When data we try to consume comes from aborted transactions, it should not be visible by default

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(100)

2.times do
  # And here we will fail the transaction just for the sake of having aborted data
  messages = elements.map { |payload| { topic: DT.topic, payload: payload } }
  Karafka::App.producer.transaction do
    Karafka::App.producer.produce_many_sync(messages)

    throw(:abort)
  end
end

# This will be successful
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert_equal DT[0], (202..301).to_a
assert_equal 302, fetch_next_offset
