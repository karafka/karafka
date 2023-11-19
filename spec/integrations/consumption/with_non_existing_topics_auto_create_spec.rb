# frozen_string_literal: true

# Karafka should be able to poll on non-existing topics when auto-create is on and should not
# raise an error about it

setup_karafka do |config|
  config.kafka[:'allow.auto.create.topics'] = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(create_topics: false) do
  100.times do |i|
    topic "#{DT.topic}#{i}" do
      consumer Consumer
    end
  end

  topic DT.topic do
    consumer Consumer
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].count >= 100 && sleep(5)
end

assert_equal elements, DT[0]
assert_equal 1, DT.data.size
