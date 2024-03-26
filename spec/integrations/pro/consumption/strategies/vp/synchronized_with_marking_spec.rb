# frozen_string_literal: true

# Karafka should be able to run marking from a synchronization block and not crash despite using
# the same lock. This ensures, that user can run synchronized code that will also mark and that
# our internal synchronization is aligned with it.

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << true

      synchronize do
        mark_as_consumed(message)
        mark_as_consumed!(message)
      end
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

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert_equal 100, fetch_next_offset
