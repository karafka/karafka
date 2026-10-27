# Release records acquired by an in-flight share fetch on unsubscribe (librdkafka patch)

The upstream report with the full analysis is in `ISSUE2.md`. This file is the brief for the
karafka-rdkafka patch.

## Problem

After `Rdkafka::ShareConsumer#unsubscribe` (`rd_kafka_share_unsubscribe()`), records acquired by a
ShareFetch that was in flight, or whose response is still queued, are never released. Other members
of the share group wait for the full acquisition lock (30s by default) and then get those records
with an incremented delivery count. `#close` does not have the problem.

Root cause (librdkafka 2.15.1, also master / v2.16.0-RC4):
- Share fetch responses (`RD_KAFKA_OP_SHARE_FETCH_RESPONSE`) are enqueued on `rk_cgrp->rkcg_q` by
  the broker thread (`src/rdkafka_fetcher.c`, around line 1048).
- They are only consumed by `rd_kafka_share_poll()`. Once unsubscribed, poll returns
  "Consumer is not subscribed to any topics" before serving `rkcg_q` (`src/rdkafka.c`, around line
  4036), so the records are never added to the inflight acknowledgement map, never acknowledged and
  never released.
- `rd_kafka_share_unsubscribe()` (`src/rdkafka_subscription.c`) only leaves the group by heartbeat.
  The share sessions, whose close makes the broker release the member's acquisitions, are closed
  only by the terminate path (`src/rdkafka_cgrp.c`, TERMINATE op handler, and
  `rd_kafka_broker_share_fetch_session_leave()` in `src/rdkafka_fetcher.c`).

Karafka no longer depends on this: a quiet share group now closes its client instead of
unsubscribing. The patch is still needed for correct `#unsubscribe` semantics and for any user of
karafka-rdkafka that unsubscribes a share consumer.

## Patch: release what the application never got

Add `dist/patches/rdkafka_share_unsubscribe_release.patch` against librdkafka 2.15.1. It is picked
up by `ext/Rakefile` (`recipe.patch_files`) and the `ext/build_*.sh` scripts. Keep the header style
of the existing patches.

What the patch has to do:

1. **On `rd_kafka_share_unsubscribe()`**, after a successful unsubscribe, drain `rkcg_q`:
   - For every `RD_KAFKA_OP_SHARE_FETCH_RESPONSE` op, call
     `rd_kafka_share_build_inflight_acks_map(rkshare, rko)` so its records are tracked, and destroy
     the message ops without handing them to the application.
   - Pass through or keep any other ops (errors etc.) as today.
   - Then set every `ACQUIRED` entry of `rkshare_inflight_acks` to `RELEASE`. Use
     `rd_kafka_share_ack_all()` as the model; it sets them to `ACCEPT` for implicit mode.
   - Dispatch the acknowledgements the same way `rd_kafka_share_commit_async()` does
     (`rd_kafka_share_build_ack_details()` plus the async commit fan-out).
2. **For responses that arrive after unsubscribe** (the in-flight fetch case, which is exactly what
   the reproduction hits), do the same release whenever the application calls into the consumer
   while unsubscribed:
   - In `rd_kafka_share_poll()`, run the drain-and-release before returning the
     "not subscribed" error.
   - Run it in `rd_kafka_share_commit_async()` / `rd_kafka_share_commit_sync()` too.

   Better, if it is feasible: run it on the main thread when the share fetch reply arrives and the
   consumer is unsubscribed (`rd_kafka_share_fetch_reply_op_cb()` in `src/rdkafka.c`). Then no
   application call is needed at all. The response op is enqueued on `rkcg_q` by the broker thread
   just before that reply is handled, so check the ordering.
3. Do not release records of the current subscription if `rd_kafka_share_subscribe()` was called
   again in the meantime. Only act while `rkshare_subscribed` is false.

Alternative approach, if 1-3 turn out to be hard: on share unsubscribe, close the share sessions
like the terminate path does, deferring for brokers with an in-flight fetch as the
`RD_KAFKA_CGRP_F_TERMINATE` branch (step 3) of `rd_kafka_share_fetch_reply_op_cb()` does. Make
`rd_kafka_share_subscribe()` open fresh sessions afterwards: today
`rd_kafka_broker_share_fetch_session_clear()` pins the epoch to -1 permanently, and
`share_session_leave_remaining_cnt` is asserted to be 0 in `rd_kafka_cgrp_terminated()`. The broker
then releases everything the member acquired, including the in-flight fetch.

Either way, the result has to be verified against a real broker with the reproduction below. This
patch was not written or built yet; the analysis comes from reading the source and from the
reproduction.

## Reproduction (Ruby, karafka-rdkafka 0.30.2, single-node broker)

```ruby
# Topic with 1 partition, group configured with share.auto.offset.reset=earliest
cfg = { "bootstrap.servers": "127.0.0.1:9092", "group.id": group,
        "share.acknowledgement.mode": "explicit" }

producer.produce(topic: topic, payload: "first").wait

a = Rdkafka::Config.new(cfg).share_consumer
a.subscribe(topic)
got = []
got = a.poll(500) while got.nil? || got.empty?
got.each { |m| a.acknowledge(m, :accept) }
a.commit_sync
2.times { a.poll(500) }             # nothing to fetch: a ShareFetch long-poll stays in flight

b = Rdkafka::Config.new(cfg).share_consumer
b.subscribe(topic)
2.times { b.poll(300) }

a.unsubscribe
20.times { |i| producer.produce(topic: topic, payload: i.to_s).wait }

t = Time.now
a.events_poll(100) while Time.now - t < 1   # A only serves its main queue from now on

start = Time.now
counts = []
while counts.size < 20 && Time.now - start < 60
  (b.poll(500) || []).each { |m| counts << m.delivery_count; b.acknowledge(m, :accept) }
end
puts "#{(Time.now - start).round(1)}s #{counts.tally}"
```

- Without the patch: `28.8s {1 => 19, 2 => 1}`, on every run.
- With `a.close` instead of `a.unsubscribe`: `0.0s {1 => 20}`.
- Expected with the patch: `0.0s {1 => 20}` with `a.unsubscribe`, at least once A has called
  `poll`/`commit` while unsubscribed (approach 2 of the patch section), or with no call at all (the
  main-thread variant or the session-close alternative).

## Tasks

1. Implement the patch, build it for every target, and make sure it applies cleanly.
2. Add a spec to the share consumer specs based on the reproduction:
   - After `unsubscribe`, another member gets every record on its first delivery and well before the
     lock duration.
   - It must fail without the patch.
3. Add a spec that `subscribe` after `unsubscribe` keeps working (records are fetched and can be
   acknowledged), since the patch touches the session and inflight state.
4. Add a CHANGELOG entry, e.g. "[Fix] Release share records acquired by an in-flight fetch when
   unsubscribing, instead of keeping them locked until the acquisition lock expires (librdkafka
   patch)."
5. Reference the upstream issue (`ISSUE2.md`, once filed on confluentinc/librdkafka) in the patch
   header, so the patch can be dropped when upstream fixes it.
