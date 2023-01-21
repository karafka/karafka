# frozen_string_literal: true

# Karafka when with VP upon error should collapse the whole collective batch and should continue
# processing in the collapsed mode after a back-off until all the "infected" messages are done.
# After that, VPs should be resumed.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

MUTEX = Mutex.new

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:flow] << [message.offset, object_id, collapsed?]
    end

    entered = false

    MUTEX.synchronize do
      if DT[:raised].empty? && DT[:flow].count >= 9
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
  produce_many(DT.topic, (0..9).to_a.map(&:to_s).shuffle)

  sleep(0.1) until DT[:raised].empty?
  sleep(2)

  sleep(0.1) until DT[:flow].count >= 20

  produce_many(DT.topic, (0..9).to_a.map(&:to_s).shuffle)

  sleep(0.1) until DT[:flow].count >= 20

  true
end

pre_collapse_index = DT[:flow].index { |row| row.first == :post_collapsed }
pre_collapse = DT[:flow][0..(pre_collapse_index - 1)]
pre_collapse_offsets = pre_collapse.map(&:first)

# Pre collapse should process all from start till crash
# We sort because order is not deterministic
previous = nil
pre_collapse_offsets.sort.each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset
  previous = offset
end

# Pre collapse should run in multiple threads
assert pre_collapse.map { |row| row[1] }.uniq.count >= 2

# None of pre-collapse should be marked as collapsed
assert pre_collapse.none? { |row| row.last }

collapsed = []
flipped = false
flipped_index = nil
last_collapsed_index = nil

DT[:flow].each_with_index do |row, index|
  next unless row.last
  next if row.first.is_a?(Symbol)

  collapsed << row
  last_collapsed_index = index

  if row.last == false
    flipped = true
    flipped_index = index
  end
end

# Once we stop getting collapsed data, it should not appear again
assert !flipped
assert_equal nil, flipped_index

# Collapsed should run in a single thread
assert_equal 1, collapsed.map { |row| row[1] }.uniq.count

# All collapsed need to be in the pre collapsed because of retry
assert (collapsed.map(&:first) - pre_collapse_offsets).empty?

# All collapsed must be in order
previous = nil
collapsed.map(&:first).each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset
  previous = offset
end

uncollapsed = DT[:flow][(last_collapsed_index + 1)..]

# All post-collapse should not be collapsed
assert uncollapsed.none?(&:last)

# Post collapse should run in multiple threads
assert uncollapsed.map { |row| row[1] }.uniq.count >= 2

# None of those processed later in parallel should be in the previous sets
assert (uncollapsed.map(&:first) & collapsed.map(&:first)).empty?
assert (uncollapsed.map(&:first) & pre_collapse.map(&:first)).empty?
