# frozen_string_literal: true

# The extended `shutdown_timeout` counterpart of the
# rebalancing/stuck_rebalance_forceful_shutdown_spec.rb scenario.
#
# The hostile conditions are identical: the group is stuck in a rebalance (a member that joined,
# got a partition routed to it and never polls, so the group cannot settle until the broker
# fences it out after its `max.poll.interval.ms`) and on affected librdkafka versions the
# consumer close blocks until that resolution (emulated here the same way as in the trigger
# spec, as recent librdkafka releases close mid-rebalance without blocking).
#
# The difference: `shutdown_timeout` is configured to outlast the rebalance resolution. The
# shutdown is slow (it waits out the remainder of the stuck rebalance inside the consumer
# close), but it stays graceful - no `app.stopping.error`, no forceful termination, no exit
# code 2 - which also means offsets and the consumer state are handed over cleanly.
#
# This is the "extend the timeout to be able to wait longer than the rebalance process itself"
# mitigation: the fastest to deploy, at the cost of slower deployments.

setup_karafka do |config|
  config.kafka[:"partition.assignment.strategy"] = "cooperative-sticky"
  # Longer than the whole stuck rebalance resolution (staller fencing + slack), so the blocked
  # close manages to finish before the supervision gives up
  config.shutdown_timeout = 60_000
end

# For how long the stalling member wedges the group (its max.poll.interval.ms). Short, so the
# rebalance resolves while the extended shutdown timeout is still running
STALL_MS = 10_000

# Extra time on top of the fencing for the group to settle
STALL_SLACK = 5

# Emulates the `rd_kafka_consumer_close` behavior from the affected librdkafka versions: close
# blocks until the in-flight rebalance resolves - here that moment does arrive, as the broker
# fences the staller out after just STALL_MS
Karafka::Connection::Client.prepend(
  Module.new do
    def close
      sleep(0.1) while DT.key?(:stall_deadline) && Time.now.to_f < DT[:stall_deadline]

      DT[:close_unblocked_at] = Time.now.to_f unless DT.key?(:close_unblocked_at)

      super
    end
  end
)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << messages.metadata.partition
  end
end

draw_topics do
  topic DT.topic do
    partitions 2
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

produce(DT.topic, "1", partition: 0)
produce(DT.topic, "1", partition: 1)

# Fires when the cooperative-sticky assignor pulls a partition from us for the stalling member
Karafka.monitor.subscribe("rebalance.partitions_revoked") do |_event|
  DT[:revoked_at] = Time.now.to_f unless DT.key?(:revoked_at)
end

start_karafka_and_wait_until do
  if DT[:consumed].empty?
    false
  else
    unless DT.key?(:stall_deadline)
      staller = setup_rdkafka_consumer(
        "partition.assignment.strategy": "cooperative-sticky",
        "max.poll.interval.ms": STALL_MS,
        # The broker-enforced minimum
        "session.timeout.ms": 6_000
      )

      # Joins the group without ever polling - the same wedge as in the trigger spec, just with
      # a short fencing time
      staller.subscribe(DT.topic)

      DT[:stallers] << staller
      DT[:stall_deadline] = Time.now.to_f + (STALL_MS / 1_000) + STALL_SLACK
    end

    # Initiate the shutdown once we are in the middle of the stuck rebalance
    if DT.key?(:revoked_at) && (Time.now.to_f - DT[:revoked_at]) > 2
      DT[:stop_requested_at] = Time.now.to_f
      true
    else
      false
    end
  end
end

shutdown_took = Time.now.to_f - DT[:stop_requested_at]

# The stuck rebalance preconditions were real
assert DT.key?(:revoked_at)

# The close really was blocked until the rebalance resolution and the shutdown waited it out
assert DT.key?(:close_unblocked_at)
assert DT[:close_unblocked_at] >= DT[:stall_deadline]

# Slow (it waited out the stuck rebalance) but nowhere near the extended shutdown_timeout and
# the forceful path. With the trigger spec 5s timeout this very scenario ends with exit code 2
assert shutdown_took < 45, "shutdown expected within the extended timeout, took #{shutdown_took}s"

# Close the staller in a bounded way (it has pending never-served rebalance callbacks)
closer = Thread.new { DT[:stallers].first.close }
closer.join(10) || closer.kill
