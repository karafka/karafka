# frozen_string_literal: true

# Karafka should run the shutdown on all the consumers that processed virtual partitions.

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 5
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      DT[:messages] << message.offset
    end

    DT[:consume_ids] << object_id
  end

  def shutdown
    DT[:shutdown_ids] << object_id
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitioner ->(msg) { msg.raw_payload }
    end
  end
end

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DT.topic, data) }

start_karafka_and_wait_until do
  DT[:messages].size >= 100
end

assert DT[:consume_ids].size >= 2
assert_equal DT[:consume_ids].uniq.sort, DT[:shutdown_ids].sort
assert_equal DT[:shutdown_ids].sort, DT[:shutdown_ids].uniq.sort
