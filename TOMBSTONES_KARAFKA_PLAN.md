# Karafka `mark_as_tombstoned` / `mark_as_tombstoned!` Implementation Plan

## Context

WaterDrop now has `tombstone_sync`/`tombstone_async` (and batch variants). This is Layer 2 from TOMBSTONES.md: consumer-level convenience methods that combine tombstone production + offset marking, so users don't need to manually wire `producer.tombstone_sync(...)` + `mark_as_consumed(message)`.

**Behavior:**
- Message is NOT a tombstone → produce tombstone (same topic, key, partition) + mark as consumed
- Message IS already a tombstone → just mark as consumed (skip redundant production)
- Message without a key → WaterDrop's contract raises `MessageInvalidError`
- Works inside `transaction {}` blocks (delegates to existing transactional `mark_as_consumed`)

## Files to Modify

### 1. `lib/karafka/base_consumer.rb` (line 17-18)

Add WaterDrop tombstone methods to the producer delegations:

```ruby
def_delegators(
  :producer, :produce_async, :produce_sync, :produce_many_async, :produce_many_sync,
  :tombstone_sync, :tombstone_async, :tombstone_many_sync, :tombstone_many_async
)
```

This gives consumers direct access to `tombstone_sync(topic:, key:, partition:)` etc. for cross-topic tombstoning use cases.

### 2. `lib/karafka/processing/strategies/default.rb`

Add `mark_as_tombstoned` and `mark_as_tombstoned!` methods. These go in Default (not Base) so they're available to all strategy combinations (Dlq, Mom, etc. all include Default).

Place after `mark_as_consumed!` (after line ~86):

```ruby
# Produces a tombstone for the message (if not already a tombstone) and marks as consumed.
#
# @param message [Messages::Message] message to tombstone
# @return [Boolean] true if offset marking succeeded
def mark_as_tombstoned(message)
  unless message.tombstone?
    producer.tombstone_async(
      topic: message.topic,
      key: message.raw_key,
      partition: message.partition
    )
  end

  mark_as_consumed(message)
end

# Produces a tombstone for the message (if not already a tombstone) and marks as consumed
# synchronously.
#
# @param message [Messages::Message] message to tombstone
# @return [Boolean] true if offset marking succeeded
def mark_as_tombstoned!(message)
  unless message.tombstone?
    producer.tombstone_sync(
      topic: message.topic,
      key: message.raw_key,
      partition: message.partition
    )
  end

  mark_as_consumed!(message)
end
```

### 3. `CHANGELOG.md`

Add under `2.5.10 (Unreleased)`:

```
- [Feature] Add `mark_as_tombstoned` and `mark_as_tombstoned!` consumer methods for producing tombstone records and marking offsets in a single call.
- [Feature] Delegate WaterDrop tombstone methods (`tombstone_sync`, `tombstone_async`, `tombstone_many_sync`, `tombstone_many_async`) from consumers.
```

## Files to Create

### 4. `spec/integrations/consumption/mark_as_tombstoned_spec.rb`

Integration test following the existing pattern (see `of_a_tombstone_record_spec.rb`):

- Produce a normal message (with key + payload)
- Consumer calls `mark_as_tombstoned!(message)`
- Second consumer on the same topic verifies a tombstone was produced (nil payload, same key)
- Verify the original message was marked as consumed

### 5. `spec/integrations/consumption/mark_as_tombstoned_on_tombstone_spec.rb`

Integration test for the "already a tombstone" path:

- Produce a tombstone (nil payload, with key)
- Consumer calls `mark_as_tombstoned!(message)` on it
- Verify NO additional tombstone produced (only the original one in the topic)
- Verify offset was still marked as consumed

## Design Rationale

- **Methods in Default strategy, not a routing feature:** `mark_as_tombstoned` should always be available (like `mark_as_consumed`). No routing DSL configuration needed for the basic OSS version. Pro can override later for `enhance_tombstone_message`, transaction wrapping, and configurable dispatch methods.
- **No new error classes:** WaterDrop's `MessageInvalidError` from the tombstone contract already covers the "missing key" case with a clear message.
- **No provenance headers in OSS:** Kept simple. Pro can add `source_topic`, `source_partition`, `source_offset` headers (like DLQ's `build_dlq_message` pattern) later.
- **Delegates WaterDrop tombstone methods:** So users can do cross-topic tombstoning directly from consumers without accessing `producer` explicitly.

## Verification

```bash
cd /home/mencio/Software/Karafka/karafka2
bundle exec ruby spec/integrations/consumption/mark_as_tombstoned_spec.rb
bundle exec ruby spec/integrations/consumption/mark_as_tombstoned_on_tombstone_spec.rb
```
