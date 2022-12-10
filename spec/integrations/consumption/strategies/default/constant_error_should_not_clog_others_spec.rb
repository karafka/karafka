# frozen_string_literal: true

# Karafka should process other partitions data using same worker in which a job failed
# Workers should not hang when a job within them fails but should be available for other jobs
# Workers should not be clogged by a failing job

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 1
end

create_topic(partitions: 3)

# Send data to all 3 partitions
# We need to remember last offset per partition as we need to seek back to always have
# 300 messages to consume tops from all 3 partitions
# There can be more if we run this in development several times
300.times do |i|
  result = produce(DT.topic, SecureRandom.hex(6), partition: i % 3)
  DT[:last_offsets][result.partition] = result.offset
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless @seeked
      seek(DT[:last_offsets][messages.metadata.partition] - 99)
      @seeked = true
      return
    end

    # We force this single partition to never process anything simulating a constant failure
    raise StandardError if messages.metadata.partition.zero?

    messages.each do |message|
      DT[message.metadata.partition] << message.metadata.partition
    end
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  # We subtract 3 as 3 values are from the offsets
  (DT.data.values.map(&:size).sum - 3) >= 200
end

# No data for failing partition
assert_equal 0, DT[0].size
assert_equal 100, DT[1].size
assert_equal 100, DT[2].size
# Extra checks for in-partition data consistency
assert_equal [1], DT[1].uniq
assert_equal [2], DT[2].uniq
