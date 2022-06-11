# frozen_string_literal: true

# Karafka should use more than one thread to consume independent topics with the pro scheduler
# Here we just aim to ensure, that we schedule all the jobs and that things operate as expected

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    # This will simulate, that the thread is busy in a bit random way, so more worker threads can
    # be occupied
    sleep(0.1)

    messages.each do
      DataCollector[topic.name] << Thread.current.object_id
    end
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    DataCollector.topics.first(10).each do |topic_name|
      topic topic_name do
        consumer Consumer
      end

      10.times { produce(topic_name, SecureRandom.uuid) }
    end
  end
end

start_karafka_and_wait_until do
  DataCollector.data.values.flatten.size >= 100
end

# All workers should be in use
assert_equal 10, DataCollector.data.keys.size
# All workers consumers should consume same number of messages
assert_equal 10, DataCollector.data.values.flatten.uniq.size
assert_equal 10, DataCollector.data.values.map(&:size).uniq.first
