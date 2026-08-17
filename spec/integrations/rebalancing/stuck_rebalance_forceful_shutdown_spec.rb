# frozen_string_literal: true

# When Karafka is being stopped while its consumer group is stuck in a rebalance that takes
# longer than `shutdown_timeout`, the shutdown must not wait forever: supervision should kick
# in, emit `app.stopping.error` with the blocking details and forcefully terminate the process
# with exit code 2 (this spec is registered in `bin/integrations` as expecting exit code 2).
#
# This reproduces the "consumption lag after deployments due to forceful shutdowns" scenario:
# rolling deployments constantly trigger rebalances and a consumer stopped mid-rebalance gets
# stuck inside `rd_kafka_consumer_close`, which on affected librdkafka versions blocks until
# the rebalance resolves. With a rebalance stuck for longer than `shutdown_timeout` (30s by
# default), each such pod ends up being killed forcefully without committing its progress,
# which after the deployment manifests as consumption lag.
#
# The stuck rebalance is real: a second group member joins (with cooperative-sticky this forces
# a revocation on the Karafka process) and never polls, so the partition routed to it stays
# inactive and the group does not settle until the broker fences that member out after its
# `max.poll.interval.ms`. The close-time hang itself is emulated on the Karafka client, because
# recent librdkafka versions no longer block inside `rd_kafka_consumer_close` in this state
# (they close mid-rebalance and let the group recover) - the hang "gets back every few versions"
# though, and Karafka's supervision contract verified here must hold whenever it does.
#
# See the mitigation counterparts of this spec:
# - rebalancing/kip_848/stuck_rebalance_graceful_shutdown_spec.rb
# - rebalancing/stuck_rebalance_static_membership_mitigation_spec.rb
# - rebalancing/stuck_rebalance_extended_timeout_mitigation_spec.rb
#
# @see https://github.com/confluentinc/librdkafka/issues/4792
# @see https://github.com/confluentinc/librdkafka/issues/4527

setup_karafka(allow_errors: %w[app.stopping.error]) do |config|
  config.kafka[:"partition.assignment.strategy"] = "cooperative-sticky"
  # Shorter than the stuck rebalance so the spec (and the forceful path) runs fast
  config.shutdown_timeout = 5_000
end

# For how long the stalling member wedges the group (its max.poll.interval.ms). It must outlast
# the shutdown timeout - this is the "rebalance longer than shutdown" precondition
STALL_MS = 60_000

# Emulates the `rd_kafka_consumer_close` behavior from the affected librdkafka versions: close
# blocks until the in-flight rebalance resolves, which here can happen only once the broker
# fences the stalling member out (it never polls, so it never leaves on its own)
Karafka::Connection::Client.prepend(
  Module.new do
    def close
      sleep(0.1) while DT.key?(:stall_deadline) && Time.now.to_f < DT[:stall_deadline]

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

# Fires when the cooperative-sticky assignor pulls a partition from us to hand it over to the
# stalling member - from that moment on the group cannot settle until the staller gets fenced
Karafka.monitor.subscribe("rebalance.partitions_revoked") do |_event|
  DT[:revoked_at] = Time.now.to_f unless DT.key?(:revoked_at)
end

# Not asserted in-process (the forceful exit is the assertion, enforced by the runner via the
# exit code) but useful when debugging this spec
Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:forceful] = true if event[:type] == "app.stopping.error"
end

start_karafka_and_wait_until do
  if DT[:consumed].empty?
    false
  else
    unless DT.key?(:stall_deadline)
      staller = setup_rdkafka_consumer(
        "partition.assignment.strategy": "cooperative-sticky",
        "max.poll.interval.ms": STALL_MS,
        "session.timeout.ms": 30_000
      )

      # Subscribing is enough to join the group (librdkafka drives the group protocol from its
      # background threads) but since this consumer never polls, it never activates its new
      # assignment and the rebalance stays unresolved until the broker fences it out
      staller.subscribe(DT.topic)

      # Keep the reference alive for the whole process lifetime so it is not garbage collected
      # (finalizers would close it and un-wedge the group)
      DT[:stallers] << staller
      DT[:stall_deadline] = Time.now.to_f + (STALL_MS / 1_000)
    end

    # Initiate the shutdown once we are in the middle of the stuck rebalance: our partition got
    # revoked for the staller and the staller will not let the group settle
    DT.key?(:revoked_at) && (Time.now.to_f - DT[:revoked_at]) > 2
  end
end

# The forceful shutdown exits with code 2 before this line is ever reached. Reaching it means
# Karafka stopped gracefully despite the consumer close being blocked by the stuck rebalance
# for longer than `shutdown_timeout`, which should never happen
assert false, "Karafka should have been forcefully terminated, not stopped gracefully"
