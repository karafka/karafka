# frozen_string_literal: true

# When consume fails while librdkafka holds prefetched messages, Karafka pauses the partition with
# backoff and moves back to the first message of the failed batch. Nothing of that partition
# should be processed during the backoff and after it the messages should come in order from the
# failed batch on, with no gap.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages before we poll
# again.

MESSAGES = 100

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 20
end

Karafka.monitor.subscribe("consumer.consuming.pause") do |event|
  next if event[:manual]

  DT[:paused_at] = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
  DT[:timeouts] << event[:timeout]
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    DT[:batches] << messages.map(&:offset)
    DT[:consumed_at] << Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

    if messages.map(&:offset).include?(30) && !DT.key?(:failed)
      DT[:failed] = messages.first.offset

      raise StandardError
    end

    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(MESSAGES))

start_karafka_and_wait_until do
  DT[:offsets].size >= MESSAGES
end

assert_equal (0...MESSAGES).to_a, DT[:offsets]
assert_equal 1, DT[:timeouts].size

failed_index = DT[:batches].index { |batch| batch.include?(30) }
# The batch after the failure starts again at its first message
assert_equal DT[:failed], DT[:batches][failed_index + 1].first

backoff_end = DT[:paused_at] + DT[:timeouts].first - 100
assert(DT[:consumed_at].none? { |at| at > DT[:paused_at] && at < backoff_end })
