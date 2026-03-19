# frozen_string_literal: true

# When migrating a consumer group that has no committed offsets, Recovery should
# raise OperationError.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

SOURCE_GROUP = SecureRandom.uuid
TARGET_GROUP = SecureRandom.uuid

raised = false

begin
  Karafka::Admin::Recovery.migrate_consumer_group(
    SOURCE_GROUP,
    TARGET_GROUP,
    lookback_ms: 60 * 1_000
  )
rescue Karafka::Admin::Recovery::Errors::OperationError
  raised = true
end

assert raised, "Expected Recovery::Errors::OperationError to be raised"
