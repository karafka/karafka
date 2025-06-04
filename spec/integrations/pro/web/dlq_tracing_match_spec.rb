# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Error references should match the DLQ traces

setup_karafka(allow_errors: %w[consumer.consume.error])
setup_web

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT[:done].size >= 3

    DT[:done] << true

    raise
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer

    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 0,
      dispatch_method: :produce_sync
    )
  end

  topic DT.topics[1] do
    active(false)
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:done].size >= 3
end

dlq_traces = Karafka::Admin
             .read_topic(DT.topics[1], 0, 5)
             .map { |message| message.headers['source_trace_id'] }

error_traces = Karafka::Admin
               .read_topic(Karafka::Web.config.topics.errors.name, 0, 5)
               .map { |message| message.payload[:details].fetch(:trace_id) }

assert_equal dlq_traces, error_traces
