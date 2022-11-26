# frozen_string_literal: true

# Karafka should track consumption rate metrics when pro
# This metrics tracker is then used internally for optimization purposes

setup_karafka do |config|
  config.concurrency = 5
  config.max_messages = 2
end

TOPICS = DT.topics.first(5)

# Simulated different performance for different topics
MESSAGE_SPEED = TOPICS.map.with_index { |topic, index| [topic, index] }.to_h

class Consumer < Karafka::BaseConsumer
  def consume
    # We add 10ms per message to make sure that the metrics tracking track it as expected
    messages.each do
      DT[0] << true

      # Sleep needs seconds not ms
      sleep MESSAGE_SPEED.fetch(messages.metadata.topic) / 1_000.0
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    TOPICS.each do |topic_name|
      topic topic_name do
        consumer Consumer
      end

      produce_many(topic_name, DT.uuids(10))
    end
  end
end

start_karafka_and_wait_until do
  DT[0].size >= 50
end

TOPICS.each do |topic_name|
  p95 = Karafka::Pro::PerformanceTracker.instance.processing_time_p95(topic_name, 0)

  message_speed = MESSAGE_SPEED.fetch(topic_name)

  assert p95 >= message_speed, "Expected #{p95} to be gteq: #{message_speed}"
  # We add 25ms to compensate for slow ci
  assert p95 <= message_speed + 25, "Expected #{p95} to be lteq: #{message_speed + 25}"
end
