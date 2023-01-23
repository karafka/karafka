# frozen_string_literal: true

# DLQ in the VP mode should collapse and skip when error occurs again in a collapsed mode also
# when there are many errors in the same collective batch. In a scenario like this, we should
# collapse and skip one after another.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 10
  config.max_messages = 100
end

MUTEX = Mutex.new

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Simulates a broken message that for example one that cannot be deserialized
      raise StandardError if message.raw_payload.to_i <= 9

      # Mark only in a collapsed mode
      mark_as_consumed(message) if collapsed?

      DT[:flow] << [message.offset, object_id, collapsed?]

      next if DT[:post].empty?

      DT[:flow2] << [message.offset, object_id, collapsed?]
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:dlq] << message
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(
        partitioner: ->(message) { message.raw_payload }
      )
      dead_letter_queue(
        topic: DT.topics[1],
        max_retries: 1
      )
    end

    topic DT.topics[1] do
      consumer DlqConsumer
    end
  end
end

produce_many(DT.topic, (0..99).to_a.map(&:to_s))

start_karafka_and_wait_until do
  if DT[:dlq].size >= 10 && DT[:flow].size >= 90
    produce_many(DT.topic, (100..109).to_a.map(&:to_s)) if DT[:post].empty?
    DT[:post] << true
    DT[:flow2].size >= 10
  else
    false
  end
end

# In the DLQ we should have all the skipped in the correct order because of the collapse-skip
assert_equal 10, DT[:dlq].size
assert_equal (0..9).to_a, DT[:dlq].map { |message| message.raw_payload.to_i }

# Skipped should not be in the flow at all
assert DT[:flow].none? { |row| row.first <= 9 }

# A batch dispatched after the recovery should use VP back
assert DT[:flow2].none?(&:last)

threads = DT[:flow2].map { |row| row[1] }.uniq.count
assert threads >= 2
