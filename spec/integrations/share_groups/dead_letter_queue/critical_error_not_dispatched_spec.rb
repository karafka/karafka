# frozen_string_literal: true

# Share group (KIP-932) dead letter queue must not dispatch a record failing with a process-critical
# error (SystemExit via `exit`) even when retries are exhausted (`max_retries: 0`). The record is
# released during the self-initiated graceful shutdown and redelivered after a restart.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      exit(1) if message.raw_payload == "critical" && !DT.key?(:second_run)

      DT[:consumed] << [message.raw_payload, message.delivery_count]
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 0)
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |_event|
  DT[:dispatched] << 1
end

produce_many(DT.topics[0], %w[a b critical])

# First run: the critical error initiates a graceful self-stop. With max_retries 0, a regular
# error would have been dispatched to the DLQ on the first attempt - the critical one must not
start_karafka_and_wait_until(reset_status: true) do
  Karafka::App.done?
end

assert_equal [], DT[:dispatched]
assert !DT[:consumed].map(&:first).include?("critical")

DT[:second_run] = true

# Second run: the released record is redelivered and processed
start_karafka_and_wait_until do
  DT[:consumed].map(&:first).include?("critical")
end

assert_equal %w[a b critical], DT[:consumed].map(&:first).uniq.sort
# At least one redelivery happened (more are possible around the stop and restart)
assert DT[:consumed].find { |payload, _| payload == "critical" }.last >= 2
assert_equal [], DT[:dispatched]
assert_equal [], Karafka::Admin.read_topic(DT.topics[1], 0, 10)
