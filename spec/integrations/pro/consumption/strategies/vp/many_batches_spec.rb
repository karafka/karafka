# frozen_string_literal: true

# When using virtual partitions, we should easily consume data with the same instances on many
# batches and until there is a rebalance or critical error, the consumer instances should
# not change

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[object_id] << message
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(
        partitioner: ->(msg) { msg.raw_payload }
      )
    end
  end
end

start_karafka_and_wait_until do
  if DT.data.values.map(&:size).sum < 1000
    produce_many(DT.topic, DT.uuids(100))
    sleep(1)
    false
  else
    true
  end
end

# It should distribute work
assert DT.data.size >= 8
# But overall number of consumer instances should be tops the concurrency
assert DT.data.size <= 10
