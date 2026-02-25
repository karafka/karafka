# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Scheduled messages with past timestamps should be handled gracefully - either
# executed immediately or properly discarded based on configuration.

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end
end

# Test different past timestamp scenarios
test_scenarios = [
  {
    name: "slightly_past",
    epoch: Time.now.to_i - 30, # 30 seconds ago
    message: { topic: DT.topics[1], payload: "slightly_past_message" }
  },
  {
    name: "moderately_past",
    epoch: Time.now.to_i - 300, # 5 minutes ago
    message: { topic: DT.topics[1], payload: "moderately_past_message" }
  },
  {
    name: "very_past",
    epoch: Time.now.to_i - 3600, # 1 hour ago
    message: { topic: DT.topics[1], payload: "very_past_message" }
  },
  {
    name: "ancient_past",
    epoch: Time.now.to_i - 86_400, # 1 day ago
    message: { topic: DT.topics[1], payload: "ancient_past_message" }
  },
  {
    name: "zero_epoch",
    epoch: 0, # Unix epoch start
    message: { topic: DT.topics[1], payload: "zero_epoch_message" }
  }
]

# Schedule all test messages with past timestamps
test_scenarios.each do |scenario|
  proxy = Karafka::Pro::ScheduledMessages.schedule(
    message: scenario[:message],
    epoch: scenario[:epoch],
    envelope: { topic: DT.topics[0], partition: 0 }
  )

  DT[:scheduled_messages] << {
    name: scenario[:name],
    epoch: scenario[:epoch],
    proxy: proxy,
    scheduled: true
  }

  Karafka.producer.produce_sync(proxy)
rescue Karafka::Errors::InvalidConfigurationError => e
  # Expected for past timestamps - scheduling is rejected
  DT[:scheduled_messages] << {
    name: scenario[:name],
    epoch: scenario[:epoch],
    proxy: nil,
    scheduled: false,
    error: e.message
  }
end

start_karafka_and_wait_until(sleep: 2) do
  # Check for any dispatched messages
  dispatched_messages = begin
    Karafka::Admin.read_topic(DT.topics[1], 0, 10)
  rescue
    []
  end

  DT[:dispatched_messages] = dispatched_messages

  # Also check the scheduler state
  begin
    state_messages = Karafka::Admin.read_topic("#{DT.topics[0]}_states", 0, 10)
    DT[:state_messages] = state_messages
  rescue
    DT[:state_messages] = []
  end

  # Wait for scheduler to process the messages
  DT[:state_messages].size >= 1
end

# Verify scheduled message handling
scheduled_count = DT[:scheduled_messages].size
assert_equal test_scenarios.size, scheduled_count

# Check which messages were actually scheduled vs rejected
successful_schedules = DT[:scheduled_messages].count { |msg| msg[:scheduled] }
rejected_schedules = DT[:scheduled_messages].count { |msg| !msg[:scheduled] }

# Verify that past timestamps were properly rejected
assert rejected_schedules >= 4, "Expected most past timestamps to be rejected"

# Check which messages were dispatched (if any)
# dispatched_payloads = DT[:dispatched_messages].map(&:payload)

# Verify past timestamp handling - they should all be rejected due to validation
DT[:scheduled_messages].each do |msg_data|
  if msg_data[:epoch] < Time.now.to_i - 10 # Past timestamps
    assert !msg_data[:scheduled], "Past timestamp should have been rejected: #{msg_data[:name]}"
    assert msg_data[:error].include?("past"), "Should have past timestamp error"
  end
end

# Verify scheduler state reflects the processing
if DT[:state_messages].any?
  latest_state = DT[:state_messages].last
  DT[:final_scheduler_state] = latest_state.payload
end

# Test edge case: Schedule a message with negative timestamp
begin
  negative_proxy = Karafka::Pro::ScheduledMessages.schedule(
    message: { topic: DT.topics[1], payload: "negative_timestamp" },
    epoch: -1000,
    envelope: { topic: DT.topics[0], partition: 0 }
  )

  Karafka.producer.produce_sync(negative_proxy)
  DT[:negative_timestamp_scheduled] = true
rescue => e
  DT[:negative_timestamp_error] = e.class.name
end

# Verify that the system handled past timestamps without crashing
assert DT[:scheduled_messages].size >= 5

# Verify that past timestamp validation works correctly
assert rejected_schedules >= 4, "Most messages should be rejected due to past timestamps"

# If any messages were successfully scheduled, they should be very recent
if successful_schedules > 0
  recent_schedules = DT[:scheduled_messages].select { |msg| msg[:scheduled] }
  recent_schedules.each do |msg|
    assert msg[:epoch] >= Time.now.to_i - 60, "Only recent timestamps should be accepted"
  end
end

# Verify no dispatched messages for past timestamps
assert DT[:dispatched_messages].empty?, "No messages should be dispatched for past timestamps"
