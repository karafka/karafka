# frozen_string_literal: true

# When dead letter queue is used and we encounter non-recoverable message, we should skip it after
# one retry and move the broken message to a separate topic

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset == 3

      DT[:offsets] << message.offset
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << [message.offset, message.raw_payload]
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 1)
    long_running_job true
    throttling(
      limit: 95,
      interval: 3_000
    )
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'consumer.consume.error'

  DT[:errors] << 1
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:offsets].uniq.count >= 99 && DT.key?(:broken)
end

# first error and one error on retry prior to moving on
# + restarting offsets errors as we move from the last offset and it goes to dlq
assert DT[:errors].count > 1

# we should not have the message that was failing
# Order random due to VP
assert_equal(((0..99).to_a - [3]).uniq.sort, DT[:offsets].uniq.sort)
