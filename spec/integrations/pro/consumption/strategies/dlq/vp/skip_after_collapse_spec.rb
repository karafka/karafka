# frozen_string_literal: true

# DLQ in the VP mode should collapse and skip when error occurs again in a collapsed mode
# After that, we should move to processing in a non-collapsed mode again

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

MUTEX = Mutex.new

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Simulates a broken message that for example one that cannot be deserialized
      raise StandardError if message.offset == 5

      # Mark only in a collapsed mode
      mark_as_consumed(message) if collapsed?

      DT[:flow] << [message.offset, object_id, collapsed?]
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

produce_many(DT.topic, (0..9).to_a.map(&:to_s))

start_karafka_and_wait_until do
  if !DT[:dlq].empty? && !DT[:flow].include?([:post_dlq])
    sleep(5)
    DT[:flow] << [:post_dlq]
    produce_many(DT.topic, (10..19).to_a.map(&:to_s))
  end

  DT[:flow].size >= 20
end

# We should not have in our data message with offset 5 as it failed
assert(DT[:flow].none? { |row| row.first == 5 })

# It should be moved to DLQ
assert_equal 5, DT[:dlq].first.headers['original_offset'].to_i

# One message should be moved
assert_equal 1, DT[:dlq].size

# After we got back to running VPs, all should run in VP
uncollapsed_index = DT[:flow].index { |row| row == [:post_dlq] }
uncollapsed = DT[:flow][(uncollapsed_index + 1)..100]

# All post-collapse should not be collapsed
assert uncollapsed.none?(&:last)

# Post collapse should run in multiple threads
assert uncollapsed.map { |row| row[1] }.uniq.count >= 2
