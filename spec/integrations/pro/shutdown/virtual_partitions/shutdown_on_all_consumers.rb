# frozen_string_literal: true

# Karafka should run the shutdown on all the consumers that processed virtual partitions.

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector[:messages] << message
    end

    DataCollector[:consume_ids] << object_id
  end

  def shutdown
    DataCollector[:shutdown_ids] << object_id
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      virtual_partitioner ->(msg) { msg.raw_payload }
    end
  end
end

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector[:messages].size >= 100
end

assert DataCollector[:consume_ids].size >= 2
assert_equal DataCollector[:consume_ids].uniq.sort, DataCollector[:shutdown_ids].sort
assert_equal DataCollector[:shutdown_ids].sort, DataCollector[:shutdown_ids].uniq.sort
