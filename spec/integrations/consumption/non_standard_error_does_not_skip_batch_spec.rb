# frozen_string_literal: true

# A batch whose processing raises a non-StandardError (a LoadError from a Rails autoload hiccup,
# NotImplementedError, etc.) must not be silently skipped. Such errors bypass the consumer-level
# error handling (which rescues StandardError only) and surface in the worker, which reports
# them and keeps the process alive. The failure must still engage the regular retry flow:
# without it the failed batch is never paused, never seeked back and never redelivered, while
# the next successful batch auto-marks its own offsets - committing PAST the failed batch.
# At-least-once would be silently violated with no crash and with offsets durably committed.

setup_karafka(allow_errors: %w[worker.process.error consumer.consume.error]) do |config|
  config.max_messages = 1
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:type]
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Fail only on the first encounter so that when the batch is redelivered (expected
      # at-least-once behavior) it processes fine and the spec can complete
      if message.offset == 2 && !DT.key?(:poisoned)
        DT[:poisoned] = true

        # NotImplementedError descends from ScriptError, not StandardError, so it skips the
        # consumer-level rescue entirely
        raise NotImplementedError, "non-StandardError raised mid-consume"
      end

      DT[:consumed] << message.offset
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(5))

started_at = Time.now

start_karafka_and_wait_until do
  all_consumed = ((0..4).to_a - DT[:consumed]).empty?
  only_poison_missing = ((0..4).to_a - DT[:consumed]) == [2]

  # Stop early when everything was consumed (expected behavior), or when everything except the
  # poisoned batch was consumed and a generous redelivery grace window has passed (the bug), or
  # on the hard timeout safety net
  all_consumed ||
    (only_poison_missing && (Time.now - started_at) > 10) ||
    (Time.now - started_at) > 30
end

# The error itself must have been reported - this spec is about the skip, not about silence on
# the instrumentation bus
assert DT[:errors].include?("consumer.consume.error"), DT[:errors]

# The batch that failed with a non-StandardError must be redelivered and eventually consumed
assert(
  DT[:consumed].include?(2),
  "offset 2 was never consumed - batch silently skipped " \
  "(consumed: #{DT[:consumed].sort}, committed next offset: #{fetch_next_offset})"
)

# And every other message exactly as well
assert_equal (0..4).to_a, DT[:consumed].uniq.sort
