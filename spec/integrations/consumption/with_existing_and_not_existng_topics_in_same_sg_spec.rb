# frozen_string_literal: true

# When Karafka starts consuming in one SG existing topic and not existing topic and auto create is
# off, it should emit an error but at the same time should consume for existing topic

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'allow.auto.create.topics'] = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] = true
  end
end

Karafka::Admin.create_topic(DT.topics[0], 1, 1)
produce_many(DT.topics[0], DT.uuids(1))

Karafka.monitor.subscribe('error.occurred') do |event|
  DT[:error] = event[:error]
end

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  DT.key?(:consumed) && DT.key?(:error)
end

assert DT[:error].message.include?('Subscribed topic not available')
assert DT[:error].message.include?(DT.topics[1])
