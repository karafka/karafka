# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should throttle and wait also on topics that are detected via patterns later on

setup_karafka do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(create_topics: false) do
  pattern(/#{DT.topic}/) do
    consumer Consumer
    throttling(
      limit: 2,
      interval: 60_000
    )
  end
end

elements = DT.uuids(20)

start_karafka_and_wait_until do
  sleep(5)

  produce_many(DT.topic, elements)

  # This needs to run for a while as on slow CIs things pick up slowly
  sleep(15)
end

assert_equal elements[0..1], DT[0]
