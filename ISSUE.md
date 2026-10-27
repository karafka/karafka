# [KIP-932] Share consumer: async acknowledgements merged out of order are rejected with INVALID_REQUEST

## Description

When several async acknowledgement commits for the same partition get queued on a broker while an
earlier acknowledgement request is still in flight, librdkafka merges their entries without
sorting them. The broker requires the acknowledgement batches of a partition to be in ascending
offset order, so it rejects the whole request with `INVALID_REQUEST`. The acknowledgements are
lost, and the records are redelivered once their acquisition lock expires (with an incremented
delivery count).

This happens with normal use of the explicit acknowledgement API: an application acknowledges the
records of one partition in a few independent chunks (for example from several worker threads),
calling `rd_kafka_share_commit_async()` after each chunk.

## Affected versions

- librdkafka 2.15.1
- master / v2.16.0-RC4 (`dddc174`)

Broker: Confluent Platform 8.3.0 (`confluentinc/cp-kafka:8.3.0`), single node, KRaft.

## Root cause

`rd_kafka_share_segregate_acks_by_leader()` in `src/rdkafka_share_acknowledgement.c` (around line
649 on master) merges an incoming ack batch into the batch already pending for the same
topic-partition on the leader broker (`rkb_share_async_ack_details`). The merge only appends the
entries ("deep-copy entries from new batch into existing, preserving order"):

```c
if (existing) {
        /* Merge: deep-copy entries from new batch into
         * existing, preserving order. The source batch
         * is then fully destroyed (freeing its entries). */
        rd_kafka_share_ack_batch_entry_t *entry;
        int j;
        RD_LIST_FOREACH(entry, &batch->entries, j) {
                rd_list_add(
                    &existing->entries,
                    rd_kafka_share_ack_batch_entry_copy(entry));
        }
        rd_kafka_share_ack_batches_destroy(batch);
}
```

Each commit's own batch is ordered, but two batches from separate commits can interleave. Appending
batch B (offsets 1, 5, 9, ...) and then batch C (offsets 2, 6, 10, ...) produces
`1, 5, 9, ..., 2, 6, 10, ...`, which the broker rejects.

The sync path, `rd_kafka_share_segregate_sync_acks_by_leader()`, does the same merge but sorts
afterwards:

```c
rd_list_sort(&existing->entries,
             rd_kafka_share_ack_entries_sort_cmp_ptr);
```

The async path is missing that call.

## How to reproduce

1. Create a topic with one partition and produce 20 records.
2. Set `share.auto.offset.reset=earliest` on the share group.
3. Create a share consumer with `share.acknowledgement.mode=explicit` and register an
   acknowledgement commit callback (`rd_kafka_share_set_acknowledgement_commit_cb()`).
4. `rd_kafka_share_poll()` until it returns all 20 records.
5. Split the records into 4 interleaved chunks (record `i` goes to chunk `i % 4`). For each chunk,
   `rd_kafka_share_acknowledge_type(..., ACCEPT)` its records and then call
   `rd_kafka_share_commit_async()`.
6. Call `rd_kafka_share_commit_sync()`, then `rd_kafka_share_poll()` once more so the callbacks are
   served.

The first commit goes out on its own. The next three are queued behind it and merged into one
request.

Expected: every acknowledgement is accepted.

Actual: the callback reports, on every run:

```
partition 0, offsets [0, 4, 8, 12, 16]                                        -> no error
partition 0, offsets [1, 5, 9, 13, 17, 2, 6, 10, 14, 18, 3, 7, 11, 15, 19]   -> Broker: Invalid request (INVALID_REQUEST)
```

Two related observations:
- Acknowledging the same records in any order and then calling **one** `rd_kafka_share_commit_async()`
  works, because the entries of one commit are built in order.
- Calling `rd_kafka_share_commit_sync()` after each chunk also works, because the sync path sorts.

So the failure needs at least two async commits queued for the same partition behind an in-flight
request.

We found this through the Ruby bindings (karafka-rdkafka), where several worker threads acknowledge
records of the same partition and each flushes with `commit_async`.

## Proposed fix

Sort the merged entries in the async path, the same way the sync path does:

```diff
--- a/src/rdkafka_share_acknowledgement.c
+++ b/src/rdkafka_share_acknowledgement.c
@@ -656,6 +656,10 @@
                                     &existing->entries,
                                     rd_kafka_share_ack_batch_entry_copy(entry));
                         }
+                        /* Batches merged from separate commits may interleave,
+                         * while the broker requires ascending ack batches. */
+                        rd_list_sort(&existing->entries,
+                                     rd_kafka_share_ack_entries_sort_cmp_ptr);
                         rd_kafka_share_ack_batches_destroy(batch);
                 } else {
                         rd_list_add(leader_rkb->rkb_share_async_ack_details,
```

(Line numbers are from 2.15.1; on master the block is around line 649.)

With this change, the same reproduction sends the merged batch as
`[1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15, 17, 18, 19]`, and the broker accepts it on every run.
