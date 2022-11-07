# frozen_string_literal: true

# When a job is marked as lrj and there is a rebalance, we should be aware that our current
# instance had the partition revoked even if it is assigned back. The assignment back should again
# start from where it left

setup_karafka do |config|
  config.max_messages = 1
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.license.token = pro_license_token
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Ensure we exceed max poll interval, if that happens and this would not work async we would
    # be kicked out of the group
    sleep(15)

    DT[0] << messages.first.raw_payload
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
    end
  end
end

# We need a second producer so we are sure that there was no revocation due to a timeout
consumer = setup_rdkafka_consumer

Thread.new do
  sleep(10)

  consumer.subscribe(DT.topic)
  consumer.poll(1_000)
end

payloads = DT.uuids(2)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].size >= 3
end

# First one will be consumed twice as first consumption happens with a rebalance. When this
# happens, we start consuming from where we left, which is from the same
assert_equal [payloads.first, payloads].flatten, DT[0]

consumer.close
