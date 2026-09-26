# frozen_string_literal: true

# Regression coverage for the sub-second `shutdown_timeout` grace period (fix karafka#3314,
# CHANGELOG 2.6.1: "Fix sub-second `shutdown_timeout` values collapsing to a zero-iteration
# supervision loop that skipped the grace period entirely"). With a `shutdown_timeout` below
# 1000 ms the `Karafka::Server` supervision loop must still grant a grace window, so an in-flight
# job can finish and commit its offset instead of being killed the instant the stop is triggered.
# Before the fix, integer division floored the iteration count to zero for any sub-second timeout,
# forcing an immediate forceful shutdown that dropped the in-flight commit. The path was covered
# by a mocked unit spec only.
#
# What this asserts, and why it is stable on a slow CI runner: the guarantee under test is that
# the in-flight *job* commits, not that the whole process shuts down gracefully. Leaving the
# consumer group on close takes several hundred ms regardless of `shutdown_timeout`, so with a
# sub-second window the listener may not wind down in time and the process then exits via the
# forceful path (exit code 2). That is expected and orthogonal - by then the job has long since
# finished and committed inside the grace window. We therefore verify the commit both when the
# shutdown happens to complete gracefully (fast host, exit 0) and, via the `app.stopping.error`
# hook, when it ends forcefully (exit 2). `bin/integrations` accepts both codes for this spec.
# `allow_errors` is on so the forceful-stop error does not abort the run on its own.

setup_karafka(allow_errors: true) do |config|
  # Sub-second grace period - the scenario the fix restored.
  config.shutdown_timeout = 800
  # Must stay below the timeout (config contract). Kept small so the in-flight job's remaining
  # work (a synchronous commit) finishes with a wide margin inside the 800 ms window even when the
  # runner is slow, and so the listener polls in short cycles.
  config.max_wait_time = 100
end

# The invariants the scenario depends on.
assert Karafka::App.config.shutdown_timeout < 1_000
assert Karafka::App.config.shutdown_timeout > Karafka::App.config.max_wait_time

CONSUMER_GROUP = Karafka::App.config.group_id

class Consumer < Karafka::BaseConsumer
  def consume
    message = messages.last

    # Signal that we are genuinely mid-processing, so the stop is triggered while this job is in
    # flight...
    DT[:processing] << true

    # ...and stay in flight until the shutdown has actually been requested. This makes the grace
    # period - not a lucky sleep duration - the thing that lets us finish, which keeps the spec
    # reliable on a slow runner. Bounded so a stuck run can never hang.
    500.times do
      break if Karafka::App.stopping?

      sleep(0.01)
    end

    # The only work left inside the grace window: a synchronous commit of the in-flight offset.
    # `mark_as_consumed!` returns whether the commit succeeded.
    DT[:committed] << mark_as_consumed!(message)
    DT[:done] << message.offset
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

# Reads the committed offset back from Kafka (an independent Admin client) and asserts the
# in-flight job finished and committed. `offset` is the next offset to consume, so a single
# message at offset 0 that was marked consumed yields a committed offset of 1.
verify_committed = lambda do
  assert_equal [true], DT[:committed]
  assert_equal [0], DT[:done]

  lags = Karafka::Admin.read_lags_with_offsets({ CONSUMER_GROUP => [DT.topic] })
  offset = lags.fetch(CONSUMER_GROUP).fetch(DT.topic).fetch(0).fetch(:offset)

  assert_equal 1, offset
end

# Forceful path: if the listener does not leave the consumer group within the sub-second window
# the process ends via a forceful stop (`app.stopping.error`, exit 2). The in-flight job has
# already finished and committed by then - assert it here, before the process exits.
Karafka::App.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "app.stopping.error"

  verify_committed.call
end

start_karafka_and_wait_until do
  DT.key?(:processing)
end

# Graceful path (fast host): the shutdown completed within the window, so we assert here.
verify_committed.call
