# frozen_string_literal: true

# After an error, in case we marked before the processing, we should just skip the broken and
# move on as we should just filter out broken one.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed(message)
      DT[:offsets] << message.offset

      raise if message.offset == 49
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(50))

extra_produced = false

start_karafka_and_wait_until do
  if DT[:offsets].count > 50
    true
  elsif DT[:offsets].count == 50 && !extra_produced
    extra_produced = true
    produce_many(DT.topic, DT.uuids(1))
    false
  else
    false
  end
end

assert_equal DT[:offsets].uniq.size, DT[:offsets].size
assert_equal DT[:offsets].sort, (0..50).to_a
