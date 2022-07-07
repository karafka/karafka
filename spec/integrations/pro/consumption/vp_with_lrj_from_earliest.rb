# frozen_string_literal: true

# Virtual partitions and long running jobs should not have any problems working together

setup_karafka do |config|
  config.max_messages = 50
  config.max_wait_time = 1_000
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.license.token = pro_license_token
  config.concurrency = 5
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    # Ensure we exceed max poll interval, if that happens and this would not work async we would
    # be kicked out of the group
    sleep(15)

    messages.each do |message|
      DataCollector[:messages] << message.raw_payload
    end

    DataCollector[:threads] << Thread.current.object_id
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      long_running_job true
      virtual_partitioner ->(msg) { msg.raw_payload }
    end
  end
end

payloads = Array.new(100) { SecureRandom.uuid }
payloads.each { |payload| produce(DataCollector.topic, payload) }

start_karafka_and_wait_until do
  DataCollector[:messages].size >= 100
end

# We should use all the threads available to process data despite it coming from a single partition
assert_equal 5, DataCollector.data[:threads].uniq.size

# We should not have any duplicated messages
assert_equal DataCollector[:messages], DataCollector[:messages].uniq

# We should have exactly as many as we expected
assert_equal 100, DataCollector[:messages].size
