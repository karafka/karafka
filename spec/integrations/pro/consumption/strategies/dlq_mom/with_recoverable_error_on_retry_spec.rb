# frozen_string_literal: true

# Same as pure DLQ version until rebalance

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.license.token = pro_license_token
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      if message.offset == 10 && !@done
        @done = true
        raise StandardError
      end

      mark_as_consumed(message)
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
    dead_letter_queue(topic: DT.topics[1], max_retries: 2)
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
  DT[:offsets].uniq.count >= 100
end

# first error and two errors on retries prior to moving on
assert_equal 1, DT[:errors].count

# All should be present
assert_equal (0..99).to_a, DT[:offsets]

# Recovered, so not in broken
assert_equal 0, DT[:broken].size
