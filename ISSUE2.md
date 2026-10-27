# [KIP-932] Share consumer: records acquired by an in-flight fetch stay locked after rd_kafka_share_unsubscribe()

## Description

When a share consumer unsubscribes while a ShareFetch request is in flight (or while a fetched
response is still queued and not yet returned by `rd_kafka_share_poll()`), the records acquired by
that fetch are never released. No other member of the share group can get them until their
acquisition lock expires (`share.record.lock.duration.ms`, 30 seconds by default). They are then
delivered again with an incremented delivery count.

Closing the consumer (`rd_kafka_share_consumer_close()`) does not have this problem: it closes the
share sessions with the brokers, and the broker releases everything the member had acquired.

Unsubscribing is the natural way for an application to stop taking work while keeping the handle
alive, for example a process that is draining before shutdown. Records it no longer intends to
process get stuck for the whole lock duration.

## Affected versions

- librdkafka 2.15.1
- master / v2.16.0-RC4 (`dddc174`)

Broker: Confluent Platform 8.3.0 (`confluentinc/cp-kafka:8.3.0`), single node, KRaft.

## How to reproduce

1. Create a topic with one partition and set `share.auto.offset.reset=earliest` on the share group.
2. Consumer A (`share.acknowledgement.mode=explicit`) subscribes, polls one record, accepts it and
   calls `rd_kafka_share_commit_sync()`.
3. A polls a couple more times with no records available, so a ShareFetch long-poll is in flight.
4. Consumer B (same group) subscribes and polls.
5. A calls `rd_kafka_share_unsubscribe()` and from then on only serves its main queue (it no longer
   calls `rd_kafka_share_poll()`, which would fail with `Consumer is not subscribed to any topics`).
6. 20 records are produced, one by one.
7. B polls until it has all 20 and accepts them.

Expected: B gets all 20 records right away, each on its first delivery.

Actual, on every run: B gets 19 records right away. The 20th arrives only after about 29 seconds,
with delivery count 2. It was acquired by A's in-flight fetch and held until its lock expired.

Variants we compared (2 runs each):

| A after step 4                                          | B got all 20 after | delivery counts |
|---------------------------------------------------------|--------------------|-----------------|
| `rd_kafka_share_unsubscribe()`                          | 28.8s              | 19 × 1, 1 × 2   |
| unsubscribe, then try to poll and release what arrives  | 28.9s              | 19 × 1, 1 × 2   |
| `rd_kafka_share_consumer_close()`                       | immediately        | 20 × 1          |

In the second variant, every `rd_kafka_share_poll()` after unsubscribe returns
`Local: Erroneous state (state): Consumer is not subscribed to any topics`. The application has no
way to get hold of the stuck records to release them itself.

In a real application, a whole batch can be held this way, not just a single record: all records
produced right after the unsubscribe were held for the full lock duration.

## Analysis

- `rd_kafka_share_unsubscribe()` (`src/rdkafka_subscription.c`) calls `rd_kafka_unsubscribe()`,
  which leaves the group through the share group heartbeat, and clears `rkshare_subscribed`. It
  does not touch the broker share sessions or the share fetch state.
- A ShareFetch already sent to a broker is still answered. The broker thread builds a
  `RD_KAFKA_OP_SHARE_FETCH_RESPONSE` op (`src/rdkafka_fetcher.c`, around line 1048) and enqueues it
  on `rk_cgrp->rkcg_q`. The records in it are already acquired by this member on the broker.
- Those responses are only consumed by `rd_kafka_share_poll()`, through
  `rd_kafka_q_serve_share_rkmessages(rkcg->rkcg_q, ...)`, which also builds the inflight
  acknowledgement map (`rd_kafka_op_process_share_fetch_response()` →
  `rd_kafka_share_build_inflight_acks_map()`).
- Once unsubscribed, `rd_kafka_share_poll()` returns the "not subscribed" error **before** serving
  `rkcg_q` (`src/rdkafka.c`, around line 4036). The queued responses are never processed: their
  records are not added to the inflight map, so they are never acknowledged nor released.
- The share sessions stay open: only the terminate path
  (`rd_kafka_cgrp_terminate()` → TERMINATE op handler in `src/rdkafka_cgrp.c`) sends the session
  close (`ShareAcknowledge` with epoch -1, `rd_kafka_broker_share_fetch_session_leave()`), which is
  what makes the broker release the member's acquisitions.

## Suggested fix

On unsubscribe, every record acquired for this member that the application never got should be
released. One of these (or both) would do it:

1. **Release queued and late responses.** When the consumer is not subscribed, drain the
   `RD_KAFKA_OP_SHARE_FETCH_RESPONSE` ops from `rkcg_q` instead of leaving them there: add them to
   the inflight map, mark their records as `RELEASE`, and dispatch the acknowledgements like an async
   commit. This has to run on unsubscribe and also for responses that arrive after it, for example
   when the main thread handles the share fetch reply (`rd_kafka_share_fetch_reply_op_cb()`), or the
   next time the application calls poll or commit while unsubscribed.
2. **Close the share sessions on unsubscribe**, the same way the terminate path does, deferring for
   brokers with an in-flight ShareFetch (as `RD_KAFKA_CGRP_F_TERMINATE` is handled in step 3 of
   `rd_kafka_share_fetch_reply_op_cb()`), so the broker releases the member's acquisitions. A later
   `rd_kafka_share_subscribe()` then needs to open new sessions. Today
   `rd_kafka_broker_share_fetch_session_clear()` pins the epoch to -1 for good, so the session state
   would need to be reset to 0.

Records the application received from `rd_kafka_share_poll()` but did not acknowledge before
unsubscribing could reasonably be released by the same mechanism.

We can provide the reproduction program on request.
