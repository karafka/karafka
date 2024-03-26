# frozen_string_literal: true

# We should start from where the offset was with direct assignments

setup_karafka

DT[:partitions] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      assign(true)
    end
  end
end

produce_many(DT.topic, DT.uuids(50))

Karafka::Admin.seek_consumer_group(DT.consumer_group, DT.topic => { 0 => 7 })

start_karafka_and_wait_until do
  DT.key?(:offsets)
end

assert_equal 7, DT[:offsets].first
