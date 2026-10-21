# frozen_string_literal: true

# Share group (KIP-932) partition whose processing constantly fails does not clog the worker nor
# the other partitions: with a single worker the healthy partitions are fully consumed, while the
# failing records are redelivered until the broker delivery count limit and then dropped.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 1
end

class Consumer < Karafka::ShareConsumer
  def consume
    partition = messages.metadata.partition

    if partition.zero?
      messages.each { |message| DT[:failing] << message.delivery_count }

      # We force this single partition to never process anything simulating a constant failure
      raise StandardError
    end

    messages.each do |message|
      DT[partition] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group(DT.topic, DT.group, 3)

elements = Hash.new { |hash, key| hash[key] = [] }

90.times do |i|
  payload = SecureRandom.hex(6)
  elements[i % 3] << payload
  produce(DT.topic, payload, partition: i % 3)
end

start_karafka_and_wait_until do
  DT[1].size >= 30 && DT[2].size >= 30 && DT[:failing].count(5) >= 30
end

# No data for the failing partition
assert_equal 0, DT[0].size
assert_equal elements[1].sort, DT[1].uniq.sort
assert_equal elements[2].sort, DT[2].uniq.sort
# Failing records were retried up to the broker delivery count limit
assert_equal [1, 2, 3, 4, 5], DT[:failing].uniq.sort
