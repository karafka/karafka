# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we get constant stream of data, we should not tick

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    @consumed = true
    DT[:consume] << true
    sleep(1)
  end

  def tick
    # There can be a case where we tick prior to consume as first poll does not yield any data
    # We do not want to raise then but after first consume with constant stream of data we should
    # never tick
    raise if @consumed
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
  end
end

Thread.new do
  loop do
    produce_many(DT.topic, DT.uuids(2))
    sleep(0.5)
  rescue WaterDrop::Errors::ProducerClosedError
    nil
  end
end

start_karafka_and_wait_until do
  DT[:consume].count >= 10
end
