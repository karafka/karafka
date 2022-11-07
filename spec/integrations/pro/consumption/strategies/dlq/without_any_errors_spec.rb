# frozen_string_literal: true

# When dead letter queue is used and we don't encounter any errors, all should be regular.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.license.token = pro_license_token
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset

      mark_as_consumed message
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
    dead_letter_queue(topic: DT.topics[1], max_retries: 2)
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
  DT[:offsets].uniq.count >= 100
end

# No errors
assert_equal 0, DT[:errors].count

# All messages consumed
assert_equal (0..99).to_a, DT[:offsets]

# No broken messages
assert_equal 0, DT[:broken].size
