# frozen_string_literal: true

# Karafka should use more than one thread to consume independent topics

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    # This will simulate, that the thread is busy in a bit random way, so more worker threads can
    # be occupied
    sleep(0.1)

    messages.each do
      DT[topic.name] << Thread.current.object_id
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    DT.topics.first(10).each do |topic_name|
      topic topic_name do
        consumer Consumer
      end

      produce_many(topic_name, DT.uuids(10))
    end
  end
end

start_karafka_and_wait_until do
  DT.data.values.flatten.size >= 100
end

# All workers should be in use
assert_equal 10, DT.data.keys.size
# All workers consumers should consume same number of messages
assert_equal 10, DT.data.values.flatten.uniq.size
assert_equal 10, DT.data.values.map(&:size).uniq.first
