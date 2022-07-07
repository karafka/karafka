# frozen_string_literal: true

# When a job is marked as vp and there is a rebalance, we should be aware that our current
# instance had the partition revoked even if it is assigned back. The assignment back should again
# start from where it left

setup_karafka do |config|
  config.max_messages = 5
  config.concurrency = 5
  config.license.token = pro_license_token
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    sleep(1)

    messages.each do |message|
      DataCollector[0] << message.raw_payload
    end


    # This will ensure we can move forward
    mark_as_consumed(messages.first)
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      virtual_partitioner ->(_) { rand }
    end
  end
end

# We need a second producer so we are sure that there was no revocation due to a timeout
consumer = setup_rdkafka_consumer

Thread.new do
  sleep(10)

  consumer.subscribe(DataCollector.topic)

  consumer.each do
    # This should never happen.
    # We have one partition and it should be karafka that consumes it
    exit! 5
  end
end

payloads = Array.new(20) { SecureRandom.uuid }

payloads.each { |payload| produce(DataCollector.topic, payload) }

start_karafka_and_wait_until do
  DataCollector[0].size >= 20
end

# There should be no duplication as our pause should be running for as long as it needs to and it
# should be un-paused only when done
assert_equal payloads.sort, DataCollector[0].sort

consumer.close
