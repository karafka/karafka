# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# In case our main producer is not transactional and we mark in a transactional way, we should not
# be allowed to mark again in a non-transactional way
# Note, that failing marking will happen automatically because of lack of mom in the routing

setup_karafka(allow_errors: true)

TRANSACTIONAL_PRODUCER = ::WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  producer_config.kafka[:'transactional.id'] = SecureRandom.uuid
  producer_config.logger = Karafka::App.config.logger
end

Karafka.monitor.subscribe('error.occurred') do |event|
  DT[:error] = event[:error]
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
      mark_as_consumed(messages.first, messages.first.offset.to_s)
    end

    DT[:after_producer] = producer
    DT[:metadata] << offset_metadata
    DT[:done] = true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:error)
end

assert DT[:error].is_a?(Karafka::Errors::NonTransactionalMarkingAttemptError)
