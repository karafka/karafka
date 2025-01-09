# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When there are future dispatches, they should not be dispatched unless the time is right
# Stats should be populated nicely though.
# One message (newest in the topic) should be dispatched though

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end
end

distant_future = Array.new(50) do |i|
  message = {
    topic: DT.topics[1],
    key: "key#{i}",
    headers: { 'b' => i.to_s },
    payload: "payload#{i}"
  }

  Karafka::Pro::ScheduledMessages.schedule(
    message: message,
    epoch: Time.now.to_i + 60 + (3_600 * i),
    envelope: { topic: DT.topics[0], partition: 0 }
  )
end

close_future = Array.new(2) do |i|
  message = {
    topic: DT.topics[1],
    key: "key#{i + 100}",
    headers: { 'b' => (i + 100).to_s },
    payload: "payload#{i + 100}"
  }

  Karafka::Pro::ScheduledMessages.schedule(
    message: message,
    epoch: Time.now.to_i + 1,
    envelope: { topic: DT.topics[0], partition: 0 }
  )
end

Karafka.producer.produce_many_sync(distant_future)
Karafka.producer.produce_many_sync(close_future)

dispatched = nil
state = nil

start_karafka_and_wait_until(sleep: 1) do
  dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 100)
  state = Karafka::Admin.read_topic("#{DT.topics[0]}_states", 0, 1).first

  next if dispatched.size < 2 || state.nil?
  next false unless state.payload[:daily].size >= 2
  next false if state.payload[:state] == 'loading'

  true
end

tomorrow_date = Date.today + 1
tomorrow_date_str = tomorrow_date.strftime('%Y-%m-%d')

# This spec is time based, so we cannot check all direct references
assert state.payload[:daily].key?(tomorrow_date_str.to_sym), state.payload

assert_equal 2, dispatched.size, state.payload

assert_equal dispatched.map(&:key).sort, %w[key100 key101], state.payload
