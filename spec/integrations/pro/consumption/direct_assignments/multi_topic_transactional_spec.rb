# frozen_string_literal: true

# We should be able to open a multi-topic transaction as long as we know which consumer is the
# source of underlying messages so we can track their offsets
#
# This works with an assumption that we have one producer
#
# @note There is code for consumer marking commented out because we want to ensure, that we mark
#   as consumed only in the transaction and that it works as expected but in a production-grade
#   system you also want to always synchronize internal state of consumers instances.
setup_karafka do |config|
  config.concurrency = 10
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

class Transactioner
  include Singleton

  def initialize
    @data = {}
  end

  def call(consumer)
    producer = Karafka.producer

    to_mark = {}

    # Will lock the producer as it has a mutex
    producer.transaction do
      @data[consumer] = consumer.messages.last

      next unless @data.size >= 2

      producer.produce_async(
        topic: DT.topics[2],
        payload: [@data.values.map(&:offset)].join(',')
      )

      @data.each do |cur_consumer, message|
        producer.transaction_mark_as_consumed(
          cur_consumer.client,
          message
        )

        to_mark[cur_consumer] = message
      end

      @data.clear
    end

    # In real world scenario you want this to run
    # to_mark.each do |consumer, message|
    #   consumer.mark_as_consumed(message)
    # end
  end
end

Transactioner.instance

class Consumer1 < Karafka::BaseConsumer
  def consume
    Transactioner.instance.call(self)
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    Transactioner.instance.call(self)
  end
end

class ValidationConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |event|
      DT[:merged] << event.raw_payload
    end
  end
end

draw_routes do
  consumer_group :merger do
    subscription_group do
      topic DT.topics[0] do
        consumer Consumer1
        assign(true)
        manual_offset_management(true)
      end
    end

    subscription_group do
      topic DT.topics[1] do
        consumer Consumer2
        assign(true)
        manual_offset_management(true)
      end
    end
  end

  topic DT.topics[2] do
    consumer ValidationConsumer
  end
end

Thread.new do
  loop do
    if [true, false].sample
      produce(DT.topics[0], DT.uuids(1).first)
      sleep(rand / 10)
      produce(DT.topics[1], DT.uuids(1).first)
    else
      produce(DT.topics[1], DT.uuids(1).first)
      sleep(rand / 10)
      produce(DT.topics[0], DT.uuids(1).first)
    end
  end
rescue WaterDrop::Errors::ProducerClosedError
  nil
end

start_karafka_and_wait_until do
  DT[:merged].size >= 10
end

sleep(2)

committed = DT[:merged].last.split(',').map(&:to_i).sort
lags = Karafka::Admin.read_lags_with_offsets['merger']
stored = lags.values.map { |parts| parts[0][:offset] - 1 }.sort

assert_equal committed, stored
