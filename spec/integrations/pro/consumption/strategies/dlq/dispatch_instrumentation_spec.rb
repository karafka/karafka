# frozen_string_literal: true

# When DLQ delegation happens, Karafka should emit appropriate event.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.license.token = pro_license_token
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end
end

Karafka.monitor.subscribe('dead_letter_queue.dispatched') do |event|
  assert !event[:message].nil?
  DT[:events] << 1
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:events].size.positive?
end

# No need for specs, if event was dispatched, we will stop, otherwise hangs.
