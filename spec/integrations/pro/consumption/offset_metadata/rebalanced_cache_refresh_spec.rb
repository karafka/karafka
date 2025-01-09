# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When rebalance occurs, even if we had cache, it should be invalidated

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed!(message, message.offset.to_s)
      DT[:metadata] << offset_metadata
    end

    unless @rebalanced
      @rebalanced = true
      DT[:trigger] = true
      sleep(5)
    end
  end
end

Thread.new do
  sleep(0.1) until DT.key?(:trigger)

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)
  consumer.poll(500)
  consumer.close
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:metadata].size >= 2
end

assert_equal %w[0 1], DT[:metadata]
