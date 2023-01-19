# frozen_string_literal: true

# When using single DLQ to handle errors from multiple topics, the dispatched message key should
# combine topic and partition to allow for good data distribution.

setup_karafka(allow_errors: %w[consumer.consume.error])

create_topic(name: DT.topics[0], partitions: 10)
create_topic(name: DT.topics[1], partitions: 10)

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.key
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[2], max_retries: 0)
  end

  topic DT.topics[1] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[2], max_retries: 0)
  end

  topic DT.topics[2] do
    consumer DlqConsumer
  end
end

elements = DT.uuids(10)
produce_many(DT.topics[0], elements)
produce_many(DT.topics[1], elements)

start_karafka_and_wait_until do
  DT[0].count >= 20
end

set = Set.new
topics = [DT.topics[0], DT.topics[1]]

DT[0].each do |key|
  assert topics.any? do |topic|
    key.start_with?("#{topic}: ")
  end

  set << key.split(': ').first
end

assert_equal 2, set.size
