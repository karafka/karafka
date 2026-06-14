# frozen_string_literal: true

# The per-partition retry attempt counter must reset when a partition is revoked. It lives in the
# listener's pauses manager keyed by topic-partition, and on revocation only the coordinator was
# discarded - the pause tracker (with its attempt count) was kept and reused as-is when the same
# listener reclaimed the partition. A message that had climbed toward its retry limit before a
# rebalance was therefore treated as already that many attempts in afterwards (with DLQ this means
# the next failure is dispatched immediately, skipping the configured retries).
#
# Here a message keeps failing so its attempt count climbs; a second consumer briefly joins the
# group and leaves, forcing a revoke + reclaim of one partition by the same listener. After the
# reclaim the attempt counter for that partition must have reset - the recorded values drop back
# down instead of continuing to climb.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 2
  config.max_messages = 1
  config.pause_timeout = 1_000
  config.pause_max_timeout = 1_000
  config.pause_with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[messages.first.partition] << coordinator.pause_tracker.attempt

    raise(StandardError, "always fail")
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 2)
  end
end

produce_many(DT.topic, %w[a], partition: 0)
produce_many(DT.topic, %w[b], partition: 1)

rdkafka = setup_rdkafka_consumer

start_karafka_and_wait_until do
  if DT[0].size >= 3 && DT[1].size >= 3 && !DT.key?(:rebalanced)
    # Force a transient rebalance: a second consumer joins (revoking a partition from the original
    # listener) and then leaves (the original listener reclaims it)
    rdkafka.subscribe(DT.topic)
    8.times { rdkafka.poll(1_000) }
    rdkafka.unsubscribe
    rdkafka.poll(1_000)
    rdkafka.close
    DT[:rebalanced] = true
    false
  elsif DT.key?(:rebalanced)
    # Let the reclaimed partition re-consume several more times after the reclaim
    DT[0].size >= 8 && DT[1].size >= 8
  else
    false
  end
end

# With the fix, the revoked + reclaimed partition's attempt counter resets, so its recorded
# attempts drop back down at some point. Without the fix every partition's attempts climb
# monotonically (the stale count is carried across the rebalance).
reset_seen = [DT[0], DT[1]].any? { |seq| seq.each_cons(2).any? { |a, b| b < a } }

assert reset_seen, "attempt never reset after revoke+reclaim: p0=#{DT[0]} p1=#{DT[1]}"
