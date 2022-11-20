# frozen_string_literal: true

# When using the DLQ with topic set to false, Karafka should not dispatch the message further but
# should apply the DLQ skipping logic anyhow.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
  config.license.token = pro_license_token
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError if messages.first.offset.zero?

    messages.each do |message|
      DT[:valid] << message.offset
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    DT[:dispatched] << true
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: false, max_retries: 2)
  end

  # This should never be reached
  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'consumer.consume.error'

  DT[:errors] << 1
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  !DT[:valid].empty?
end

assert_equal 3, DT[:errors].size
assert_equal [], DT[:dispatched]
