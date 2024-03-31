# frozen_string_literal: true

# Karafka should use default deserializers when defaults exist and topic is detected

setup_karafka do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] = messages.first
  end
end

draw_routes(create_topics: false) do
  defaults do
    deserializers(
      payload: ->(_) { 1 },
      key: ->(_) { 2 },
      headers: ->(_) { { 'test' => 3 } }
    )
  end

  pattern(/.*#{DT.topics[1]}/) do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  unless @created
    sleep(5)
    produce_many("#{DT.topics[0]}-#{DT.topics[1]}", DT.uuids(1))
    @created = true
  end

  DT.key?(0)
end

assert_equal DT[0].payload, 1
assert_equal DT[0].key, 2
assert_equal DT[0].headers, { 'test' => 3 }
