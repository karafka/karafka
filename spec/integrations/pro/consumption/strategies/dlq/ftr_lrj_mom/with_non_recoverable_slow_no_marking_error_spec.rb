# frozen_string_literal: true

# Karafka should be able to recover from non-critical error when using lrj with mom but because
# of no marking, we should move forward, however upon picking up work, we should start from zero
# This can be risky upon rebalance but we leave it to the advanced users to manage.
# of no marking, we should move forward, however upon picking up work, we should move offset
# based on the crashes one by one from the first consumed or from zero

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    @sleep ||= 20
    @sleep -= 5
    @sleep = 1 if @sleep < 1

    sleep @sleep

    messages.each do |message|
      raise StandardError if message.offset == 1

      DT[0] << message.offset
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[1] << message.headers['original_offset'].to_i
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    long_running_job true
    dead_letter_queue(topic: DT.topics[1], max_retries: 2)
    manual_offset_management true
    throttling(limit: 5, interval: 5_000)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

produce_many(DT.topics[0], DT.uuids(100))

start_karafka_and_wait_until do
  DT.key?(1) && DT[0].uniq.size >= 3
end

assert_equal [0, 1], DT[1].uniq
assert DT[1].size >= 1
assert_equal 0, fetch_next_offset
