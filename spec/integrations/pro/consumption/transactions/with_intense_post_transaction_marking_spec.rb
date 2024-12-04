# frozen_string_literal: true

# Post transaction marking should not crash anything and should work with connections pool

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.concurrency = 10
  config.max_messages = 20
end

DP = -> { produce_many(DT.topic, DT.uuids(50)) }

require 'connection_pool'

PRODUCERS = ConnectionPool.new(size: 5, timeout: 5) do
  me = ::WaterDrop::Producer.new do |producer_config|
    producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
    producer_config.logger = Karafka::App.config.logger
    producer_config.kafka[:'transactional.id'] = SecureRandom.uuid
    # We need to wait a lot sometimes because we create a lot of new topics and this can take
    # time
    producer_config.max_wait_timeout = 120_000 # 2 minutes
  end

  me.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)

  me.monitor.subscribe('error.occurred') do |event|
    p event
    exit 10
  end

  me
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      PRODUCERS.with do |producer|
        transaction(producer) do
          produce_async(topic: 'test', payload: '0')
          mark_as_consumed(message)
        end
      end

      mark_as_consumed!(message)
    end

    DP.call
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    multiplexing(max: 5)

    topic DT.topic do
      config(partitions: 5)
      consumer Consumer
    end
  end
end

DP.call

start_karafka_and_wait_until do
  DT.key?(:done)
end
