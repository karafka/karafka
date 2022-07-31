# frozen_string_literal: true

# Karafka should use the same coordinator for all the jobs in a group

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
  config.max_messages = 5
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each { |message| DataCollector[:messages] << message.offset }

    DataCollector[:coordinators_ids] << coordinator.object_id
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
  DataCollector[:messages].count >= 100
end

assert_equal 1, DataCollector[:coordinators_ids].uniq.size
