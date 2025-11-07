# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should correctly handle transactional producers from a ConnectionPool with
# multiplexing, ensuring transactional integrity across concurrent consumers

Bundler.require(:default)

mod = Module.new do
  def self.token
    ENV.fetch('KARAFKA_PRO_LICENSE_TOKEN')
  end
end

Karafka.const_set(:License, mod)
require 'karafka/pro/loader'

Karafka::Pro::Loader.require_all

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.concurrency = 10
  config.max_messages = 20
end

DP = -> { produce_many(DT.topic, DT.uuids(50)) }
DT[:accu] = {}

PRODUCERS = ConnectionPool.new(size: 5, timeout: 5) do
  me = WaterDrop::Producer.new do |producer_config|
    producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
    producer_config.logger = Karafka::App.config.logger
    producer_config.kafka[:'transactional.id'] = SecureRandom.uuid
    producer_config.max_wait_timeout = 120_000 # 2 minutes
  end

  me.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)

  # Crash on any producer errors
  me.monitor.subscribe('error.occurred') do |event|
    puts event
    exit 10
  end

  me
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      PRODUCERS.with do |producer|
        transaction(producer) do
          DT[:accu][message.partition] << 1
          produce_async(topic: DT.topic, payload: '')
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
  DT[:accu].values.all? { |acc| acc.size >= 100 }
end
