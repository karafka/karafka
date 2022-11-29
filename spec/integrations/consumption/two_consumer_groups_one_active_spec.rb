# frozen_string_literal: true

# Karafka should be able to consume one topic when two consumer groups are defined but only one
# is active

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      group = topic.consumer_group.name
      DT[group] << message.payload
    end
  end
end

draw_routes do
  consumer_group DT.consumer_groups.first do
    topic DT.topics.first do
      consumer Consumer
    end
  end

  consumer_group DT.consumer_groups.last do
    topic DT.topics.last do
      consumer Consumer
    end
  end
end

# Listen only on one consumer group
Karafka::App.config.internal.routing.active.consumer_groups = [DT.consumer_groups.first]

jsons = Array.new(10) { { SecureRandom.uuid => rand.to_s } }

# We send same messages to both topics, but except only one to run and consume
jsons.each do |data|
  produce(DT.topics.first, data.to_json)
  produce(DT.topics.last, data.to_json)
end

start_karafka_and_wait_until do
  DT.data.values.flatten.size >= 10
end

keys = DT.data.keys

assert_equal jsons, DT[keys[0]]
assert_equal 1, DT.data.size
