# frozen_string_literal: true

# When using single DLQ to handle errors from multiple topics, the dispatched message key should
# match the partition of origin

setup_karafka(allow_errors: %w[consumer.consume.error])

create_topic(name: DT.topics[0], partitions: 100)
create_topic(name: DT.topics[1], partitions: 100)

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [message.key, message.headers['original_partition']]
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

100.times do |i|
  elements = DT.uuids(10)
  produce_many(DT.topics[0], elements, partition: i)
  produce_many(DT.topics[1], elements, partition: i)
end


start_karafka_and_wait_until do
  DT[0].count >= 20
end

DT[0].each do |key|
  assert_equal key[0], key[1]
end

assert DT[0].map(&:first).uniq.count > 1
