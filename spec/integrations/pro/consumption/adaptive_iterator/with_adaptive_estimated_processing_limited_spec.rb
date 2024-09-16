# frozen_string_literal: true

# With adaptive margin, if the max cost of message would cause reaching max poll, we should seek
# back

setup_karafka do |config|
  config.concurrency = 1
  config.max_messages = 100
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    each do |message|
      sleep((message.offset % 3))
      DT[:offsets] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    adaptive_iterator(
      active: true,
      safety_margin: 1
    )
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:offsets].size >= 10
end

assert_equal DT[:offsets], (0..9).to_a
