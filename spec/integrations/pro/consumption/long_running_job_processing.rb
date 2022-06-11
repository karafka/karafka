# frozen_string_literal: true

# When a job is marked as lrj, it should keep running longer than max poll interval and all
# should be good. It should continue processing after resume and should pick up next messages

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

    DataCollector[0] << messages.first.raw_payload
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      long_running_job true
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

payloads = Array.new(2) { SecureRandom.uuid }

payloads.each { |payload| produce(DataCollector.topic, payload) }

start_karafka_and_wait_until do
  DataCollector[0].size >= 2
end

assert_equal payloads, DataCollector[0]

consumer.close
