# frozen_string_literal: true

# When handling failing messages from a many partitions and there are many errors, standard DLQ
# will not provide strong ordering warranties inside DLQ.
# If you need strong ordered DLQ, please look into getting the Pro version.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:partitions] << message.partition
    end

    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message.partition
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    config(partitions: 10)
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end

  topic DT.topics[1] do
    config(partitions: 10)
    consumer DlqConsumer
  end
end

10.times do |i|
  elements = DT.uuids(100)
  produce_many(DT.topic, elements, partition: i)
end

start_karafka_and_wait_until do
  DT[:partitions].uniq.count >= 2 &&
    DT[:broken].uniq.count >= 5
end

# No need for any assertions as if it would pipe only to one, it would hang and crash via timeout
