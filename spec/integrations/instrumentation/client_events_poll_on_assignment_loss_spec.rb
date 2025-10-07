# frozen_string_literal: true

# This spec verifies that the client.events_poll event is emitted when assignment loss is
# detected, and that the AssignmentsTracker properly clears assignments in response.

require_relative '../../integrations_helper'

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

# Subscribe to client.events_poll to verify the event is emitted
Karafka.monitor.subscribe('client.events_poll') do |event|
  DT[:events_poll_events] << {
    time: Time.now.to_f,
    client_id: event[:caller].id,
    subscription_group_id: event[:subscription_group].id
  }
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    # Store initial assignment state
    DT[:initial_assignments] = Karafka::App.assignments.dup

    # Simulate processing that exceeds max.poll.interval.ms
    sleep(15)

    # Store final assignment state after sleep
    DT[:final_assignments] = Karafka::App.assignments.dup
    DT[:done] = true
  end
end

draw_routes(Consumer)

produce(DT.topic, '1')

start_karafka_and_wait_until do
  DT.key?(:done)
end

# Verify client.events_poll events were emitted during processing
assert DT[:events_poll_events].size > 1, "Expected multiple events_poll events, got #{DT[:events_poll_events].size}"

# Verify the events contain proper metadata
first_event = DT[:events_poll_events].first
assert first_event[:client_id], 'Event should include client_id'
assert first_event[:subscription_group_id], 'Event should include subscription_group_id'

# Verify assignments were present initially
initial_topic = DT[:initial_assignments].keys.first
assert initial_topic, 'Should have initial topic assignment'
assert DT[:initial_assignments][initial_topic].any?, 'Should have initial partition assignments'

# Verify assignments were cleared after exceeding max.poll.interval.ms
assert DT[:final_assignments].empty?, 'Assignments should be cleared after assignment loss'

# Verify timing - events_poll should have been called multiple times during the 15s sleep
event_count = DT[:events_poll_events].size
# With tick_interval of 5s and 15s sleep, we should see at least 3 events
assert event_count >= 3, "Expected at least 3 events_poll calls during 15s, got #{event_count}"
