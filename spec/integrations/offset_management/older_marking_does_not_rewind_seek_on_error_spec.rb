# frozen_string_literal: true

# Marking an offset older than one already marked must be ignored - we only move forward. The
# guard previously ignored only the exact last marked offset, so marking any older message rewound
# `coordinator.seek_offset`. A subsequent error then paused and seeked back to that rewound offset
# (via `retry_after_pause` -> `pause(seek_offset)`) and reprocessed every message in between,
# producing duplicates.
#
# Here the first batch marks its last message, then its first (older) message, then raises. With
# the fix the older marking is ignored, the error seeks forward (nothing to reprocess) and every
# offset is seen exactly once. Without it, the seek rewinds and the in-between offsets repeat.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }

    # Only on the first batch: mark forward, then mark an older offset, then raise so the
    # error-driven retry pauses and seeks to coordinator.seek_offset
    return unless DT[:marked].empty?
    return if messages.size < 2

    DT[:marked] << true

    mark_as_consumed!(messages.last)
    mark_as_consumed!(messages.first)

    raise(StandardError, "trigger pause and seek")
  end
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errored_at] = Time.now.to_f if event[:type] == "consumer.consume.error"
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  # Wait until the failure fired and the error-driven retry/seek has had time to run (and, without
  # the fix, to reprocess the rewound range)
  DT.key?(:errored_at) && (Time.now.to_f - DT[:errored_at]) > 10
end

# Sanity: the out-of-order marking + error scenario actually ran
assert DT[:marked].size >= 1, "the mark-older-then-raise scenario did not run"

# The older marking must be ignored, so the error's seek does not rewind and nothing is reprocessed
assert_equal DT[:offsets].uniq.size, DT[:offsets].size, DT[:offsets]
