# frozen_string_literal: true

# A process-critical error (SystemExit via `exit`) under manual offset management with a DLQ
# must NOT be dispatched even when retries are exhausted (max_retries: 0 dispatches on the
# first attempt for regular errors). The batch stays paused and only the manually marked
# offsets are committed, so after the restart the failed batch is redelivered.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      exit(1) if message.offset == 2 && !DT.key?(:second_run)

      DT[:consumed] << message.offset

      mark_as_consumed(message)
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
    manual_offset_management(true)
  end
end

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |_event|
  DT[:dispatched] << 1
end

produce_many(DT.topics[0], DT.uuids(5))

start_karafka_and_wait_until(reset_status: true) do
  DT[:consumed].size >= 2 && Karafka::App.done?
end

assert_equal [], DT[:dispatched]
assert_equal [0, 1], DT[:consumed].uniq.sort
assert_equal 2, fetch_next_offset(DT.topics[0])

DT[:second_run] = true

start_karafka_and_wait_until do
  ((0..4).to_a - DT[:consumed].uniq).empty?
end

assert_equal (0..4).to_a, DT[:consumed].uniq.sort
assert_equal [], DT[:dispatched]
