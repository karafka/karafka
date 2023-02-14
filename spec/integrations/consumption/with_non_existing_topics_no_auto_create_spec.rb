# frozen_string_literal: true

# Karafka should raise an error when it encounters non-existing topic and no auto topic creation

# We need to allow errors so we can track them and check the propagation
setup_karafka(allow_errors: true) do |config|
  config.kafka[:'allow.auto.create.topics'] = false
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

Karafka.monitor.subscribe('error.occurred') do |event|
  DT[:events] << event
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:events].count >= 1
end

payload = DT[:events].last.payload

assert_equal Karafka::Connection::Client, payload[:caller].class
assert_equal 'connection.client.poll.error', payload[:type]
assert_equal :unknown_topic_or_part, payload[:error].code
