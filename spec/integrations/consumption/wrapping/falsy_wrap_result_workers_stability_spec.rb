# frozen_string_literal: true

# Workers must not die when a user-defined #wrap returns a falsy value. The worker loop decides
# whether to continue based on the processing flow result, and the #wrap return value (a
# documented public API with no truthiness requirement) must not be interpreted as a worker stop
# request. A #wrap ending with an assignment or a logger call returning nil is idiomatic user
# code - even our own docs example ends with `self.producer = default_producer`.
#
# Before the fix, each consume job whose #wrap returned nil silently killed its worker thread
# (no error, no instrumentation event). After `concurrency` jobs the pool was fully drained and
# the process became a zombie: the listener kept polling and enqueuing jobs that no worker would
# ever pick up, until max.poll.interval.ms kicked it out of the group.

setup_karafka do |config|
  # With 2 workers, the pre-fix behavior is deterministic: exactly 2 single-message jobs get
  # consumed (each killing one worker) and the remaining messages are never processed
  config.concurrency = 2
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.offset
    end
  end

  # Ends with nil on the consume flow - the framework must tolerate any return value here
  def wrap(action)
    yield

    nil if action == :consume
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(6))

started_at = Time.now

start_karafka_and_wait_until do
  # Assert inside the wait block: when workers are dead, initiating the regular shutdown would
  # hang on the never-picked-up shutdown jobs and end in a forceful exit! that would swallow
  # the assertion message
  if (Time.now - started_at) > 30
    assert_equal(
      6,
      DT[:consumed].size,
      "workers died after falsy #wrap result: only #{DT[:consumed].size}/6 messages consumed"
    )
  end

  DT[:consumed].size >= 6
end

assert_equal 6, DT[:consumed].size
