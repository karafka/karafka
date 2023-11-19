# frozen_string_literal: true

# When marking ahead, where there is no current offset to materialize on first batch, no offset
# should be marked and we should start from zero again

setup_karafka do |config|
  config.max_messages = 50
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      next unless message.offset.zero?

      DT[:done] << true

      mark_as_consumed Karafka::Messages::Seek.new(topic, partition, 51)
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:done].count.positive? && sleep(1)
end

assert_equal 0, fetch_first_offset, nil
