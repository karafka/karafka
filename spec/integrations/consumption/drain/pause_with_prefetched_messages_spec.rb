# frozen_string_literal: true

# When we pause a partition from consume while librdkafka holds its prefetched messages, none of
# them should be processed while it is paused. After the resume, consumption should continue from
# the pause offset with no gap and no duplicate.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages before we poll
# again.

MESSAGES = 100
PAUSE = 2_000

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    DT[:consumed_at] << Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

    messages.each do |message|
      DT[:offsets] << message.offset

      next unless message.offset == 30 && !DT.key?(:paused_at)

      DT[:paused_at] = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      pause(31, PAUSE)

      return
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(MESSAGES))

start_karafka_and_wait_until do
  DT[:offsets].size >= MESSAGES
end

assert_equal (0...MESSAGES).to_a, DT[:offsets]
# Nothing is consumed between the pause and its expiration
assert(DT[:consumed_at].none? { |at| at > DT[:paused_at] && at < DT[:paused_at] + PAUSE - 100 })
