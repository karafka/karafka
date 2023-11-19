# frozen_string_literal: true

# If we mark virtual offsets that cannot be materialized to a state, we should start from beginning
# on errors. Throttling should not impact it in any way

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 500
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    # Try marking a fake seek offset
    mark_as_consumed Karafka::Messages::Seek.new(topic.name, partition, 750)

    raise StandardError
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    throttling(limit: 50, interval: 250)
    virtual_partitions(
      partitioner: ->(_msg) { rand(9) }
    )
  end
end

produce_many(DT.topic, DT.uuids(1000))

start_karafka_and_wait_until do
  DT[:offsets].count > 500
end

assert DT[:offsets].count(0) > 1
