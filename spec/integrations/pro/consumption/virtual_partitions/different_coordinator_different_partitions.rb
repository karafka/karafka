# frozen_string_literal: true

# Karafka should not use the same coordinator for jobs from different partitions

TOPIC = 'integrations_19_02'

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
  config.max_messages = 5
  config.initial_offset = 'latest'
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
      virtual_partitioner ->(_) { rand }
    end
  end
end

start_karafka_and_wait_until do
  produce(TOPIC, '1', partition: 0)
  produce(TOPIC, '1', partition: 1)

  DataCollector[:messages].count >= 100
end

assert_equal 2, DataCollector[:coordinators_ids].uniq.size
