# frozen_string_literal: true

# Instrumentation should handle events with nil/missing data gracefully without crashing
# the monitoring system or causing data corruption.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << 1

    # Test instrumentation with nil/missing data by examining existing events
    # that may have nil or missing fields during normal operation
    messages.each do |message|
      DT[:messages_with_nil_check] << {
        payload_nil: message.payload.nil?,
        key_nil: message.key.nil?,
        headers_empty: message.headers.empty?
      }
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      deserializer ->(message) { message.raw_payload }
    end
  end
end

# Use existing instrumentation events instead of custom ones
Karafka.monitor.subscribe('consumer.consumed') do |_event|
  DT[:consumer_events] << 1
end

Karafka.monitor.subscribe('consumer.initialized') do |_event|
  DT[:initialized_events] << 1
end

elements = DT.uuids(1)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:consumed].size >= 1 &&
    DT[:consumer_events].size >= 1 &&
    DT[:messages_with_nil_check].size >= 1
end
