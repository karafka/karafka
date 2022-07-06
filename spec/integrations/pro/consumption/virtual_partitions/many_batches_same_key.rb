# frozen_string_literal: true

# When using virtual partitions and having a partitioner that always provides the same key, we
# should always use one thread despite having more available

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector[object_id] << message
    end
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      virtual_partitioner ->(_msg) { '1' }
    end
  end
end

start_karafka_and_wait_until do
  if DataCollector.data.values.map(&:size).sum < 1000
    elements = Array.new(100) { SecureRandom.uuid }
    elements.each { |data| produce(DataCollector.topic, data) }
    sleep(1)
    false
  else
    true
  end
end

assert_equal 1, DataCollector.data.size
