# frozen_string_literal: true

# We should be able to replace the default producer with a transactional one
# We set the default producer to a broken location so in case our wrapping would not work, it will
# crash

setup_karafka(allow_errors: %w[consumer.consume.error])

TRANSACTIONAL_PRODUCER = ::WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  producer_config.kafka[:'transactional.id'] = SecureRandom.uuid
  producer_config.logger = Karafka::App.config.logger
end

DEFAULT_PRODUCER = ::WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = { 'bootstrap.servers': '127.0.0.1:9090' }
  producer_config.logger = Karafka::App.config.logger
end

Karafka::App.config.producer = DEFAULT_PRODUCER

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:producer] = producer
    DT[:done] = true

    raise
  end

  def wrap(_action)
    default_producer = producer
    self.producer = TRANSACTIONAL_PRODUCER
    yield
    self.producer = default_producer
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 0,
      dispatch_method: :produce_sync
    )
  end
end

TRANSACTIONAL_PRODUCER.produce_sync(topic: DT.topic, payload: '1')

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal TRANSACTIONAL_PRODUCER, DT[:producer]
