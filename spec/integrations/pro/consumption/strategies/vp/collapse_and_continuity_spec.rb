# frozen_string_literal: true

# Karafka when with VP upon error should collapse the whole collective batch and should continue
# processing in the collapsed mode after a back-off until all the "infected" messages are done.
# After that, VPs should be resumed.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
  config.max_wait_time = 10_000
end

MUTEX = Mutex.new
SLEEP = 30

class Consumer < Karafka::BaseConsumer
  def consume
    return if messages.count == 1
    return unless DT[:flow].include?([:post_warmup])

    messages.each do |message|
      DT[:flow] << [message.offset, object_id, collapsed?]
    end

    entered = false

    MUTEX.synchronize do
      if DT[:raised].empty?
        DT[:raised] << true
        entered = true
      end
    end

    if entered
      sleep(2)
      DT[:flow] << [:post_collapsed]
      raise StandardError
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
    end
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, %w[0])

  sleep(SLEEP)
  DT[:flow] << [:post_warmup]

  produce_many(DT.topic, (0..9).to_a.map(&:to_s).shuffle)

  sleep(SLEEP)
  DT[:flow] << [:restored_vp]

  produce_many(DT.topic, (0..9).to_a.map(&:to_s).shuffle)

  sleep(SLEEP)

  true
end

steps = {}
step_key = nil

DT[:flow].each do |step|
  if step.first.is_a?(Symbol)
    step_key = step.first
    steps[step_key] ||= []
  else
    steps[step_key] << step
  end
end

# First batch should run in many VPs
assert_equal (1..10).to_a, steps[:post_warmup].map(&:first).sort
assert steps[:post_warmup].map { |row| row[1] }.uniq.count >= 2

# Then we should have a second round that is collapsed with the same data but running in the same
# partition and in order
assert_equal (1..10).to_a, steps[:post_collapsed].select(&:last).map(&:first)
assert_equal 1, steps[:post_collapsed].select(&:last).map { |row| row[1] }.uniq.count

# After the recovery we should have regular VP flow again
assert_equal (11..20).to_a, steps[:restored_vp].map(&:first).sort
assert steps[:restored_vp].map { |row| row[1] }.uniq.count >= 2
