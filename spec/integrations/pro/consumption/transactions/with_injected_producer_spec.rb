# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# In case our main producer is not transactional or for any other reason, we should be able to
# inject a transactional one and use it if we want.

setup_karafka

TRANSACTIONAL_PRODUCER = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  producer_config.kafka[:'transactional.id'] = SecureRandom.uuid
  producer_config.logger = Karafka::App.config.logger
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    DT[:before_producer] = producer

    # Without an injected producer this would not work as the default producer is not transactional
    transaction(TRANSACTIONAL_PRODUCER) do
      produce_async(topic: DT.topic, payload: rand.to_s)
      DT[:during_producer] = producer
      producer.produce_async(topic: DT.topic, payload: rand.to_s)
    end

    # Without mom we cannot mark in a transactional fashion because later on karafka would try to
    # mark transactional without transactional producer (default)
    mark_as_consumed!(messages.first, messages.first.offset.to_s)

    DT[:after_producer] = producer
    DT[:metadata] << offset_metadata
    DT[:done] = true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal '0', DT[:metadata].first
assert_equal Karafka.producer, DT[:before_producer]
assert_equal TRANSACTIONAL_PRODUCER, DT[:during_producer]
assert_equal Karafka.producer, DT[:after_producer]
