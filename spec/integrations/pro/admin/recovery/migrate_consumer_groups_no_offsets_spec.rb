# frozen_string_literal: true

# When batch-migrating and a source group has no committed offsets,
# the operation should raise an error listing the missing source.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
  end
end

SOURCE1 = SecureRandom.uuid
SOURCE2 = SecureRandom.uuid
TARGET1 = SecureRandom.uuid
TARGET2 = SecureRandom.uuid

# Only commit offsets for SOURCE1, not SOURCE2
Karafka::Admin.seek_consumer_group(
  SOURCE1,
  { DT.topics[0] => { 0 => 10 } }
)

sleep(2)

error_raised = false

begin
  Karafka::Admin::Recovery.migrate_consumer_groups(
    { SOURCE1 => TARGET1, SOURCE2 => TARGET2 },
    lookback_ms: 60 * 1_000
  )
rescue Karafka::Admin::Recovery::Errors::OperationError => e
  error_raised = true
  assert e.message.include?(SOURCE2),
         "Expected error to mention #{SOURCE2}, got: #{e.message}"
end

assert error_raised, "Expected OperationError to be raised"
