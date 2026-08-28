# frozen_string_literal: true

# A process-critical error (SystemExit via `exit`) on a DLQ-enabled topic must NOT be dispatched
# to the DLQ even when retries are exhausted (max_retries: 0 dispatches on the very first
# attempt for regular errors). Dispatching would mark the message as consumed and commit past
# it, contradicting the critical-error contract: the batch stays paused and unmarked during the
# self-initiated graceful shutdown and is redelivered after a restart.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      exit(1) if message.offset == 2 && !DT.key?(:second_run)

      DT[:consumed] << message.offset
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end
end

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |_event|
  DT[:dispatched] << 1
end

produce_many(DT.topics[0], DT.uuids(5))

# First run: the critical error initiates a graceful self-stop. With max_retries 0, a regular
# error would have been dispatched to the DLQ on the first attempt - the critical one must not
start_karafka_and_wait_until(reset_status: true) do
  DT[:consumed].size >= 2 && Karafka::App.done?
end

# Nothing was dispatched to the DLQ
assert_equal [], DT[:dispatched]

# The committed offset points at the failed batch, not past it
assert_equal 2, fetch_next_offset(DT.topics[0])

DT[:second_run] = true

# Second run: the failed batch is redelivered and everything processes to the end
start_karafka_and_wait_until do
  ((0..4).to_a - DT[:consumed].uniq).empty?
end

assert_equal (0..4).to_a, DT[:consumed].uniq.sort

# Still nothing in the DLQ
assert_equal [], DT[:dispatched]
