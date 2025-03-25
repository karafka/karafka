# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we get constant stream of data on other partition, our unused partition should anyhow tick
# only once every tick interval

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def tick
    DT[messages.metadata.partition] << Time.now.to_f
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    periodic true
  end
end

Thread.new do
  loop do
    produce_many(DT.topic, DT.uuids(2), partition: 0)
    sleep(0.1)
  rescue WaterDrop::Errors::ProducerClosedError
    nil
  end
end

start_karafka_and_wait_until do
  DT[1].size >= 5
end

previous = nil

DT[1].each do |time|
  unless previous
    previous = time

    next
  end

  # 5 seconds is the default tick interval and we should not tick more often
  # on an unused but assigned partition
  assert time - previous >= 5

  previous = time
end
