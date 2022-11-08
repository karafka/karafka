# frozen_string_literal: true

# When we do not perform any markings as consumed we should nonetheless skip one after another
# starting from the beginning of the batch on failed batches.
#
# This should allow us to move one by one slowly and should mark on successful batches.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 6
  config.max_wait_time = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset == 10

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
  subscription_group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 1)
    end
  end

  # We put those in separate subscription groups so their results aren't polled together
  subscription_group do
    topic DT.topics[1] do
      consumer DlqConsumer
    end
  end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'consumer.consume.error'

  DT[:errors] << 1
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:offsets].uniq.count >= 99 &&
    !DT[:broken].empty? &&
    DT[:broken].last[1] == elements[10] &&
    DT[:broken].size >= 2 &&
    DT[:errors].count >= 3
end

# first error, retry and same for more messages from batch previous to failing
assert DT[:errors].count > 3

# we should not have the message that was failing
assert_equal (0..99).to_a - [10], DT[:offsets].uniq

# Previous to broken should be present
assert DT[:broken].map(&:first)[-2] < 10

assert DT[:broken].size >= 2
