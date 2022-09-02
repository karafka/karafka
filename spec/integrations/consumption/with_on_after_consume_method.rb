# frozen_string_literal: true

# Karafka has a `#after_consume` method. This method should not be used as part of the official
# API but we add integration specs here just to make sure it runs as expected.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end

  # We should have access here to anything that we consumed, so we duplicate this and we can
  # compare that later
  def on_after_consume
    messages.each do |message|
      DT["post-#{message.metadata.partition}"] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert_equal DT['post-0'], DT[0]
assert_equal 2, DT.data.size
