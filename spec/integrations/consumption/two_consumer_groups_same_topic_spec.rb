# frozen_string_literal: true

# Karafka should be able to consume same topic using two consumer groups

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
    topic DT.topic do
      consumer Consumer
    end
  end

  consumer_group DT.consumer_groups.last do
    topic DT.topic do
      consumer Consumer
    end
  end
end

jsons = Array.new(100) { { SecureRandom.uuid => rand.to_s } }
jsons.each { |data| produce(DT.topic, data.to_json) }

start_karafka_and_wait_until do
  DT.data.values.flatten.size >= 200
end

keys = DT.data.keys

assert_equal 2, DT.data.size
assert_equal 100, DT[keys[0]].size
assert_equal 100, DT[keys[1]].size
assert_equal jsons, DT[keys[0]]
assert_equal jsons, DT[keys[1]]
