# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Same trace id should be present when instrumenting errors and during the DLQ dispatch
# Since we retry 2 times, only proper dispatch traces should be present in the final set

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 10
end

Karafka.monitor.subscribe('error.occurred') do |event|
  DT[:traces] << event[:caller].errors_tracker.trace_id if DT[:errors].size % 3 == 2
  DT[:errors] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if DT[:traces].size < 10

      mark_as_consumed(message)
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 2,
      independent: true
    )
  end

  topic DT.topics[1] do
    active(false)
  end
end

produce_many(DT.topic, (0..99).to_a.map(&:to_s))

start_karafka_and_wait_until do
  DT[:traces].size >= 10
end

sleep(1)

dlq_traces = Karafka::Admin
             .read_topic(DT.topics[1], 0, 100)
             .map { |message| message.headers['source_trace_id'] }

assert_equal(
  DT[:traces],
  dlq_traces
)
