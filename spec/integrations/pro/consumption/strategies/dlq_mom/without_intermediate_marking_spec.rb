# frozen_string_literal: true

# When we do not mark and user does not mark, we will end up with an infinite loop.
# This is expected and user should deal with this on his own.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 6
  config.license.token = pro_license_token
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset == 10

      DT[:offsets] << message.offset
    end
  end
end

class DlqConsumer < Karafka::Pro::BaseConsumer
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
    manual_offset_management(true)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
    manual_offset_management(true)
  end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'consumer.consume.error'

  DT[:errors] << 1
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:offsets].count >= 20
end

consumer = setup_rdkafka_consumer
consumer.subscribe(DT.topics[0])

first_offset = nil

consumer.each do |message|
  first_offset = message.offset

  break
end

consumer.close

# None of the offsets should have been committed
assert_equal 0, first_offset
