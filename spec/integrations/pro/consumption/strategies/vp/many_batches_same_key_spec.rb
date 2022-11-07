# frozen_string_literal: true

# When using virtual partitions and having a partitioner that always provides the same key, we
# should always use one thread despite having more available

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[object_id] << message.offset
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(
        partitioner: ->(_msg) { '1' }
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

assert_equal 1, DT.data.size
