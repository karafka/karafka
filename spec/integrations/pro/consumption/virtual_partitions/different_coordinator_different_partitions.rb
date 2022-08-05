# frozen_string_literal: true

# Karafka should not use the same coordinator for jobs from different partitions

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
  config.max_messages = 5
  config.initial_offset = 'latest'
end

create_topic(partitions: 2)

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each { |message| DT[:messages] << message.offset }

    DT[:coordinators_ids] << coordinator.object_id
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitioner ->(_) { rand }
    end
  end
end

start_karafka_and_wait_until do
  produce(DT.topic, '1', partition: 0)
  produce(DT.topic, '1', partition: 1)

  DT[:messages].count >= 100
end

assert_equal 2, DT[:coordinators_ids].uniq.size
