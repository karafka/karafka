# frozen_string_literal: true

# When enable.partition.eof is on (Eof polling strategy) and the partition is exhausted,
# EOF triggers an immediate yield rather than blocking until max_wait_time expires.
# This is the intentional low-latency characteristic of the Eof strategy: contrast with
# the Batch strategy, which blocks up to max_wait_time when fewer than max_messages arrive.

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.max_messages = 200
  # Very long - should never be the exit condition; EOF should preempt it
  config.max_wait_time = 60_000
  config.shutdown_timeout = 120_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:data] << message.offset
    end
  end

  def eofed
    DT[:eof] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    eofed true
  end
end

3.times { produce(DT.topic, "data") }

started_at = Time.now.to_f

start_karafka_and_wait_until do
  DT[:data].size >= 3 && DT.key?(:eof)
end

time_taken = Time.now.to_f - started_at

# EOF should have caused early exit well before the 60s max_wait_time
assert time_taken < 30, time_taken
