# frozen_string_literal: true

# After we collapse, we should skip messages we marked as consumed, except those that were not
# processed.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise if message.offset == 49 && !collapsed?

      mark_as_consumed(message) if message.offset > 10

      DT[0] << message.offset
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      manual_offset_management(true)
      consumer Consumer
      virtual_partitions(
        partitioner: ->(message) { message.offset < 20 || message.offset == 49 ? 0 : 1 }
      )
    end
  end
end

produce_many(DT.topic, DT.uuids(50))

start_karafka_and_wait_until do
  DT[0].count >= 50
end

assert_equal DT[0].uniq.count, DT[0].count
