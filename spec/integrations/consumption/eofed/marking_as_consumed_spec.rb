# frozen_string_literal: true

# We should be able to mark as consumed from the `#eofed`

setup_karafka do |config|
  config.kafka[:'enable.partition.eof'] = true
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def eofed
    return if messages.empty?

    mark_as_consumed!(messages.last)
    DT[:marked] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    eofed true
  end
end

produce_many(DT.topic, DT.uuids(2))

Thread.new do
  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(2)
  rescue WaterDrop::Errors::ProducerClosedError
    nil
  end
end

start_karafka_and_wait_until do
  DT.key?(:marked)
end

assert fetch_next_offset > 0
