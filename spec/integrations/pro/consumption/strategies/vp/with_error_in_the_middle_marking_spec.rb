# frozen_string_literal: true

# When using VPs and marking, we should end up with the last materialized offset sent to Kafka
# while the rest of things should be picked up until this offset

class Listener
  def on_error_occurred(_event)
    DT[:errors] << true
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset

      if message.offset == 25 && DT[:offsets].count(25) < 2
        sleep(1)
        raise StandardError
      end

      mark_as_consumed(message)
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

start_karafka_and_wait_until do
  if DT[:offsets].size >= 50 && DT[:offsets].count(25) >= 2
    true
  else
    produce_many(DT.topic, DT.uuids(10))

    sleep(1)
    false
  end
end

24.times do |offset|
  assert_equal 1, DT[:offsets].count(offset)
end

assert_equal 2, DT[:offsets].count(25)
