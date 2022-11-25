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

    # This will ensure we can move forward
    mark_as_consumed(messages.first)
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

thread = Thread.new do
  sleep(10)

  consumer.subscribe(DT.topic)

  while DT[:done].empty?
    data = consumer.poll(500)
    # This should never happen.
    # We have one partition and it should be karafka that consumes it
    exit!(5) if data
  end

  consumer.close
end

payloads = DT.uuids(2)
payloads.each { |payload| produce(DT.topic, payload) }

start_karafka_and_wait_until do
  DT[0].uniq.size >= 2
end

# There can be duplication of processing on LRJ if there is a revocation and another LRJ job is
# pushed after partition is regained. We should however not loose any messages
assert_equal payloads, DT[0].uniq

DT[:done] << true

thread.join
