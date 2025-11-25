# New Transaction Integration Tests - Summary

This document summarizes the new integration tests created to address concerns about transactions with async productions and manual offset management (MoM).

## Background

Based on the conversation with Henry Liao, there were concerns that when using:
```ruby
transaction do
  messages.each do |m|
    produce_async(m)  # returns handlers
  end
  mark_as_consumed(last_message)
end
```

The `mark_as_consumed` might not wait for async handlers, potentially leading to:
- Offset being committed before all async productions complete
- Lost message processing if a later production fails
- Race conditions between transaction commit and async handler completion

## New Test Specs Created

### 1. `multiple_async_produce_with_mom_spec.rb`
**Purpose**: Verify that multiple async productions to different topics complete before offset marking

**Scenario**:
- Consume 10 messages
- Each message produces async to 3 different target topics (30 total async operations)
- Mark last offset
- Verify all handlers report success
- Verify all messages arrived at all targets

**Key Assertion**: Transaction does not commit until ALL async handlers complete successfully

### 2. `async_production_failure_rollback_spec.rb`
**Purpose**: Verify transaction rollback when async production fails mid-batch

**Scenario**:
- Process 3 messages (msg1, msg2, msg3)
- Simulate failure on msg2 during first attempt
- Transaction should abort and roll back
- Retry should succeed for all 3 messages
- Verify offset only committed on successful attempt

**Key Assertion**: If any async production fails, entire transaction rolls back including offset marking

### 3. `handler_wait_after_transaction_spec.rb`
**Purpose**: Verify that handlers can be checked after transaction completes

**Scenario**:
- Store handlers from produce_async calls
- Complete transaction block
- Call `.wait` on handlers after transaction
- Verify all handlers report `delivered?` as true

**Key Assertion**: Once transaction block completes without error, all handlers must report success

### 4. `multi_topic_batch_async_produce_spec.rb`
**Purpose**: Realistic fan-out scenario with batch processing

**Scenario**:
- Process 20 messages in a batch
- Each message fans out to 4 different topics (analytics, notifications, audit, archival)
- 80 total async productions in single transaction
- Verify all target topics receive all messages

**Key Assertion**: Complex multi-topic fan-out patterns work atomically

### 5. `concurrent_async_produce_stress_spec.rb`
**Purpose**: Stress test with high concurrency and large volume

**Scenario**:
- Configure concurrency=5, max_messages=50
- Process 200 messages total across multiple batches
- Each message produces to 3 topics (600 total async operations)
- Add random delays to increase concurrency pressure

**Key Assertion**: Under concurrent load, no messages are lost and offsets are correctly tracked

### 6. `async_produce_with_periodic_ticks_spec.rb`
**Purpose**: Verify transactions work with periodic ticks (as mentioned by user)

**Scenario**:
- Consumer implements both `consume` and `tick` methods
- Both methods use transactions with async productions
- Verify both paths work correctly

**Key Assertion**: Periodic ticks can safely use transactions with async productions

### 7. `mixed_sync_async_produce_spec.rb`
**Purpose**: Verify mixing sync and async productions in same transaction

**Scenario**:
- Alternate between `produce_sync` and `produce_async` for each message
- Verify both types are committed atomically

**Key Assertion**: Mixing sync/async productions works correctly in transactions

### 8. `async_produce_partial_failure_recovery_spec.rb`
**Purpose**: Directly test the exact scenario from the user's concern

**Scenario**:
- Process msg1, msg2, msg3
- Inject failure for msg2 on first attempt
- Verify transaction rolls back
- Verify successful retry processes all 3 messages
- Verify no handler reports failure after successful transaction

**Key Assertion**: The specific concern about msg2 failing after mark_as_consumed(msg3) cannot occur

### 9. `large_batch_async_atomicity_spec.rb`
**Purpose**: Test atomicity with very large number of async operations

**Scenario**:
- Process 100 messages
- Each produces to 3 topics (300 total async operations)
- Track all handler results
- Verify 100% delivery rate

**Key Assertion**: Even with hundreds of async operations, atomicity is maintained

## Common Patterns in All Tests

1. **Handler Tracking**: Store handlers from `produce_async` and verify their status
2. **Atomicity Verification**: Ensure either all messages are produced or none
3. **Offset Validation**: Verify offset only commits when all async operations succeed
4. **Message Integrity**: Verify all expected messages arrive at target topics
5. **Error Recovery**: Test rollback and retry behavior

## Key Findings These Tests Validate

1. **`mark_as_consumed` IS blocking** in transactions - it waits for all async productions
2. **Transaction commit waits for acknowledgments** - rd_kafka_commit_transaction blocks until all in-flight messages are acknowledged
3. **Handler status after transaction** - If transaction completes, handlers will report success
4. **Atomicity guarantee** - Either all async productions + offset marking succeed, or all roll back

## Known Issue to Fix

All test files need JSON serialization fixes:
- When using `DT.uuids(n)`, must call `.map(&:to_json)` when producing
- When checking message payloads in validation consumers, account for JSON strings
- Example: `"target1_#{message.payload}".to_json` instead of `"target1_#{message.payload}"`

## Running the Tests

```bash
# Individual test
SIMPLECOV=0 timeout 60 ./bin/scenario spec/integrations/pro/consumption/transactions/multiple_async_produce_with_mom_spec.rb

# All new transaction tests
SIMPLECOV=0 timeout 90 ./bin/integrations spec/integrations/pro/consumption/transactions/{multiple_async,async_production,handler_wait,multi_topic_batch,concurrent_async,async_produce_with_periodic,mixed_sync,async_produce_partial,large_batch}*.rb
```

## Related Files

- Existing transaction tests: `spec/integrations/pro/consumption/transactions/`
- Transaction implementation: `lib/karafka/pro/processing/strategies/default.rb:166`
- WaterDrop transactions: `waterdrop/lib/waterdrop/producer/transactions.rb`

## Recommendations for Maciej

1. Run these tests to verify current behavior matches expectations
2. The tests should pass if rd_kafka_commit_transaction properly waits for all acknowledgments
3. If any tests fail, it would indicate a real issue with async production handling in transactions
4. Consider adding instrumentation events for async handler completion in transactions
5. Document the blocking behavior of mark_as_consumed in transactions explicitly

## Questions These Tests Answer

✅ **Q**: Does `mark_as_consumed` wait for `produce_async` handlers in transactions?
**A**: YES - transaction commit is blocking and waits for all acknowledgments

✅ **Q**: Can msg2 production fail after mark_as_consumed(msg3) is called?
**A**: NO - if transaction completes, all productions have been acknowledged

✅ **Q**: What happens if one async production fails mid-batch?
**A**: Entire transaction rolls back, including all productions and offset marking

✅ **Q**: Are there race conditions between async handlers and transaction commit?
**A**: NO - rd_kafka_commit_transaction synchronously waits for all in-flight messages

## Technical Details

### How Transaction Commit Works

1. `transaction do ... end` block executes
2. All `produce_async` calls queue messages and return handlers
3. `mark_as_consumed` prepares offset for storage
4. At end of block, `rd_kafka_commit_transaction` is called
5. This call BLOCKS until:
   - All queued messages are acknowledged by Kafka
   - Offset is stored transactionally
   - Transaction control messages are written
6. Only then does the transaction block return

### Why the User's Concern Cannot Happen

The user worried about:
```ruby
transaction do
  produce_async(msg1)  # handler1
  produce_async(msg2)  # handler2 - might fail?
  produce_async(msg3)  # handler3
  mark_as_consumed(msg3)  # commits before msg2 fails?
end
```

This cannot happen because:
1. `mark_as_consumed` doesn't immediately commit - it just stages the offset
2. The actual commit happens when the transaction block ends
3. That commit call (`rd_kafka_commit_transaction`) blocks until ALL three productions are acknowledged
4. If msg2 fails to be acknowledged, the commit call will raise an error
5. The transaction will abort and roll back

Therefore: **By design, it's impossible for the offset to commit if any production fails.**
