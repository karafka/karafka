# frozen_string_literal: true

# When independent flag is on and a message recovers mid-batch with sync marking, the next failing
# message in the same batch should start from attempt 1 and should run at most `max_retries + 1`
# times

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.offset] << attempt

      raise StandardError if message.raw_payload == "fail-once" && attempt == 1
      raise StandardError if message.raw_payload == "always-fail"

      mark_as_consumed!(message)
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:dlq] << message.raw_payload }
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 2, independent: true)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

produce_many(DT.topic, %w[fail-once always-fail ok])

start_karafka_and_wait_until do
  DT.key?(2) && DT.key?(:dlq)
end

assert_equal [1, 2], DT[0]
assert_equal [1, 2, 3], DT[1]
assert_equal %w[always-fail], DT[:dlq]
