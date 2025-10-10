# frozen_string_literal: true

# In the DLQ flow custom producer should be used when defined

setup_karafka(allow_errors: %w[consumer.consume.error])

SUPER_PRODUCER = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset == 0

      DT[:offsets] << message.offset

      mark_as_consumed message
    end
  end

  def producer
    SUPER_PRODUCER
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message.offset
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 2,
      dispatch_method: :produce_sync
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

elements = DT.uuids(5)
produce_many(DT.topic, elements)

Karafka::App.config.producer = WaterDrop::Producer.new do |config|
  config.deliver = true
  config.kafka = {
    'bootstrap.servers': 'localhost:999',
    'message.timeout.ms': 1_000
  }
end

start_karafka_and_wait_until do
  DT[:offsets].uniq.size > 1
end

assert_equal DT[:offsets], (1..4).to_a
