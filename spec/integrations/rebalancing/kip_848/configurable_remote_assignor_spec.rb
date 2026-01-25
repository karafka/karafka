# frozen_string_literal: true

# Test that KIP-848 works with configurable remote assignor
# The new consumer protocol supports different server-side assignors like 'uniform' and 'range'

setup_karafka(consumer_group_protocol: true) do |config|
  # Configure the remote assignor to use uniform distribution
  config.kafka[:"group.remote.assignor"] = "uniform"
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload
    end
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 4)
    consumer Consumer
  end
end

# Produce test messages
produce_many(DT.topic, DT.uuids(40))

start_karafka_and_wait_until do
  DT[:consumed].size >= 40
end

assert_equal 40, DT[:consumed].size
assert_equal 40, DT[:consumed].uniq.size
