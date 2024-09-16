# frozen_string_literal: true

# When processing messages with iterator enabled and reaching max.poll.interval, we should never
# get any errors and processing should be consecutive

setup_karafka do |config|
  config.concurrency = 1
  config.max_messages = 100
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    each do |message|
      sleep(1)
      DT[:offsets] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    adaptive_iterator(
      active: true,
      safety_margin: 20
    )
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:offsets].size >= 20
end

assert_equal DT[:offsets], (0..19).to_a
