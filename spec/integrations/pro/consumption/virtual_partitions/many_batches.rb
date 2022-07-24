# frozen_string_literal: true

# When using virtual partitions, we should easily consume data with the same instances on many
# batches and until there is a rebalance or critical error, the consumer instances should
# not change

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
      virtual_partitioner ->(msg) { msg.raw_payload }
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

# It should distribute work
assert DataCollector.data.size >= 8
# But overall number of consumer instances should be tops the concurrency
assert DataCollector.data.size <= 10
