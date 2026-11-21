# frozen_string_literal: true

# A user-defined StandardError subclass added to `internal.processing.critical_errors` must be
# handled as a process-critical error: it is never dispatched to the DLQ (even with no retries
# left), the failed batch stays unmarked, the process stops gracefully and the batch is
# redelivered after the restart.

FatalError = Class.new(StandardError)

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
  config.internal.processing.critical_errors = [
    *config.internal.processing.critical_errors,
    FatalError
  ]
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise FatalError if message.offset == 2 && !DT.key?(:second_run)

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
