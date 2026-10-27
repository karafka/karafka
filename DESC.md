# Fix out-of-order share-group async acknowledgements (librdkafka patch)

## Problem

librdkafka 2.15.1, the version bundled in karafka-rdkafka 0.30.2, has a bug in the share
consumer's async acknowledgement path. Current upstream master has the same bug.

`rd_kafka_share_segregate_acks_by_leader` is in `src/rdkafka_share_acknowledgement.c`, around line
645 in 2.15.1. While an async ack request is in flight, every further `commit_async` (and acks sent
along with a poll) for the same partition is appended to the batch already waiting for that
partition. The entries are appended **without sorting**.

The broker requires ack batches in ascending offset order. When two or more commits queue up for
the same partition with interleaved offsets, the broker rejects the whole request with
`RD_KAFKA_RESP_ERR_INVALID_REQUEST`. Those acknowledgements are lost, and the records are
redelivered once their acquisition lock expires.

The sync path, `rd_kafka_share_segregate_sync_acks_by_leader` in the same file, already calls
`rd_list_sort(..., rd_kafka_share_ack_entries_sort_cmp_ptr)` after merging. Only the async path is
missing it.

Karafka hits this when several threads acknowledge records of the same partition and each flushes
with `commit_async`. Pro virtual partitions for share groups do exactly that. Karafka now flushes
once per partition, which mitigates it, but async commits still sweep up the pending acks of every
partition. With multiple partitions it can still happen.

## Fix

Add a new patch, `dist/patches/rdkafka_share_async_ack_sort.patch`. It's picked up automatically by
`ext/Rakefile` (`recipe.patch_files`) and by the `ext/build_*.sh` scripts
(`find_patches`/`apply_patches`). Match the header and path style of the existing patches (BSD
license comment, `librdkafka_<version>/src/...` paths, same `-p` level):

```diff
# This patch is released under the 2-clause BSD license, same as librdkafka
#
--- librdkafka_2.15.1/src/rdkafka_share_acknowledgement.c
+++ librdkafka_2.15.1/src/rdkafka_share_acknowledgement.c
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

The surrounding block is the `if (existing) { ... }` merge branch inside
`rd_kafka_share_segregate_acks_by_leader`, which has the comment "Merge: deep-copy entries from new
batch into existing, preserving order".

## Reproduction (verified against 0.30.2)

Single-partition topic. Set the share group to `share.auto.offset.reset=earliest` with
`incremental_alter_configs` on the group resource, produce 20 records, and use a share consumer
with `share.acknowledgement.mode=explicit`:

```ruby
consumer.acknowledgement_commit_callback = ->(offsets, err) { puts "#{offsets.inspect} #{err.inspect}" }
msgs = consumer.poll(1000) # all 20 records
msgs.group_by.with_index { |_, i| i % 4 }.values.each do |slice|
  slice.each { |m| consumer.acknowledge(m, :accept) }
  consumer.commit_async
end
consumer.commit_sync
consumer.poll(2000)
```

- **Before the patch** (every run):

  ```
  [{partition: 0, offsets: [0, 4, 8, 12, 16]}] nil
  [{partition: 0, offsets: [1, 5, 9, 13, 17, 2, 6, 10, 14, 18, 3, 7, 11, 15, 19]}] Broker: Invalid request (invalid_request)
  ```

- **After the patch** (every run):

  ```
  [{partition: 0, offsets: [0, 4, 8, 12, 16]}] nil
  [{partition: 0, offsets: [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15, 17, 18, 19]}] nil
  ```

Acking out of order before a **single** commit is fine, and so is a `commit_sync` per slice. The
failure needs at least two `commit_async` calls queued behind an in-flight one.

## Tasks

1. Add the patch above and make sure it applies cleanly on every build target (Rakefile recipe,
   linux gnu/musl x86_64/aarch64, macOS).
2. Add a spec under the share consumer specs based on the repro. Its acknowledgement commit callback
   must report no error, and the merged offsets must be ascending. It must fail without the patch.
3. Add a CHANGELOG entry, e.g. "[Fix] Sort merged share-group async acknowledgements so the broker
   does not reject them with `invalid_request` (librdkafka patch)."
4. Optionally open an upstream issue or PR on confluentinc/librdkafka with the same one-line fix,
   and reference it in the patch header so the patch can be dropped when upstream fixes it.
