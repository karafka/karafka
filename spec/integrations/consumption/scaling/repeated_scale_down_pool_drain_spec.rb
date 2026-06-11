# frozen_string_literal: true

# Repeated scale-down requests issued while all workers are busy must account for downscale
# sentinels that are already in-flight. Workers deregister only when they pick a sentinel up, so
# a busy pool reports a stale size to subsequent scale calls.
#
# Before the fix, each scale(1) call recomputed its delta from that stale size and enqueued
# another full round of sentinels. Once the busy workers finished their jobs, every one of them
# picked up a sentinel and exited, draining the pool to zero workers - below the documented
# minimum of one - and permanently stalling all processing: jobs kept being enqueued but no
# worker existed to pick them up.

setup_karafka do |config|
  config.concurrency = 2
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload
    end

    return if DT.key?(:scaled)

    DT[:busy] << topic.name

    # Keep this worker busy until both scale-down requests were issued, so the second request
    # observes the same (stale) pool size as the first one. The time escape is a CI safety net
    # only - the spec flow releases via DT[:scaled]
    started_at = Time.now
    sleep(0.05) until DT.key?(:scaled) || (Time.now - started_at) > 15
  end
end

# Two subscription groups give us two independent listeners, so both workers are guaranteed to
# hold a blocking job at the same time regardless of how messages would be batched within a
# single poll
draw_routes do
  DT.topics.first(2).each do |topic_name|
    subscription_group "sg-#{topic_name}" do
      topic topic_name do
        consumer Consumer
      end
    end
  end
end

DT.topics.first(2).each { |topic_name| produce(topic_name, "block") }

scaled = false
follow_up_produced = false
started_at = Time.now

start_karafka_and_wait_until do
  # Issue both scale-down requests only once both workers are busy with blocking jobs
  if !scaled && DT[:busy].uniq.size >= 2
    DT[:size_before] = Karafka::Server.workers.size

    Karafka::Server.workers.scale(1)
    # An idempotent-looking repeat - reconciliation loops are an expected usage pattern of the
    # dynamic scaling API. It must not enqueue another round of sentinels
    Karafka::Server.workers.scale(1)

    scaled = true
    DT[:scaled] = true
  end

  # Once the downscale settled, deliver a follow-up message that the surviving worker must
  # process
  if scaled && !follow_up_produced && Karafka::Server.workers.size <= 1
    produce(DT.topics.first, "follow-up")
    follow_up_produced = true
  end

  # Assert inside the wait block: with a fully drained pool, initiating the regular shutdown
  # would hang on the never-picked-up shutdown jobs and end in a forceful exit! that would
  # swallow the assertion message
  if (Time.now - started_at) > 30
    assert_equal(
      1,
      Karafka::Server.workers.size,
      "expected the pool to keep 1 worker, drained to #{Karafka::Server.workers.size}"
    )

    assert(
      DT[:consumed].include?("follow-up"),
      "follow-up message never consumed despite a worker supposedly surviving"
    )
  end

  done = DT[:consumed].include?("follow-up")

  # Capture the settled pool size while Karafka still runs - after this block returns, the
  # regular shutdown stops all workers and the size legitimately drops to zero
  DT[:size_settled] = Karafka::Server.workers.size if done && !DT.key?(:size_settled)

  done
end

# Both workers were busy when scaling was requested
assert_equal 2, DT[:size_before]

# The pool must never drop below one worker, no matter how many times scale-down was requested
assert_equal 1, DT[:size_settled]

# The surviving worker processed work that arrived after the downscale
assert DT[:consumed].include?("follow-up")
