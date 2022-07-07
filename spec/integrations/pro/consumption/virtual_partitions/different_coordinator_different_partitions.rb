# frozen_string_literal: true

# Karafka should not use the same coordinator for jobs from different partitions

TOPIC = 'integrations_19_02'

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
  config.max_messages = 5
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each { |message| DataCollector[:messages] << message }

    DataCollector[:coordinators_ids] << coordinator.object_id
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic TOPIC do
      consumer Consumer
      virtual_partitioner ->(msg) { msg.raw_payload }
    end
  end
end

elements = Array.new(50) { SecureRandom.uuid }

elements.each do |data|
  produce(TOPIC, data, partition: 0)
  produce(TOPIC, data, partition: 1)
end

start_karafka_and_wait_until do
  DataCollector[:messages].count >= 100
end

assert_equal 2, DataCollector[:coordinators_ids].uniq.size
