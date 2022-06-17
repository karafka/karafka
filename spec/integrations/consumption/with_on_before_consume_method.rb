# frozen_string_literal: true

# Karafka has a `#before_consume` method. This method should not be used as part of the official
# API but we add integration specs here just to make sure it runs as expected.

setup_karafka

class Consumer < Karafka::BaseConsumer
  # We should have access here to anything that we can get when consuming, so we duplicate
  # this and we can compare that later
  def on_before_consume
    messages.each do |message|
      DataCollector["prep-#{message.metadata.partition}"] << message.raw_payload
    end
  end

  def consume
    messages.each do |message|
      DataCollector[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector[0].size >= 100
end

assert_equal DataCollector['prep-0'], DataCollector[0]
assert_equal 2, DataCollector.data.size
