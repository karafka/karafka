# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to dispatch to DLQ with usage of the enhanced errors tracking details

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end

  private

  def enhance_dlq_message(dlq_message, _skippable_message)
    dlq_message[:headers]['error_class'] = errors_tracker.last.class.to_s
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end
end

Karafka.monitor.subscribe('dead_letter_queue.dispatched') do |event|
  assert !event[:message].nil?
  DT[:events] << 1
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  # We sleep to wait on the dlq flush since async
  DT[:events].size.positive? && sleep(2)
end

assert_equal(
  Karafka::Admin.read_topic(DT.topics[1], 0, 1).last.headers['error_class'],
  'StandardError'
)
