# frozen_string_literal: true

# When we pause a lost partition, it should not have any impact on us getting the data after
# we get it back (if we get it back)

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    if DT.key?(:paused)
      DT[:again] = true
    else
      sleep(15)
      pause(messages.last.offset, 100_000_000)
      DT[:paused] = true
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:again)
end
