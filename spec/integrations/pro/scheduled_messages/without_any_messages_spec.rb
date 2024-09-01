# frozen_string_literal: true

# When there are no messages at all, we should publish nothing except an empty state

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])
end

state = nil

start_karafka_and_wait_until(sleep: 1) do
  state = Karafka::Admin.read_topic("#{DT.topics[0]}_states", 0, 1).first
end

today = Date.today.strftime('%Y-%m-%d')

assert_equal state.headers, { 'zlib' => 'true' }
assert_equal state.payload[:schema_version], '1.0.0'
assert_equal state.payload[:state], 'loaded'
assert_equal state.payload[:daily], { today.to_sym => 0 }
assert state.payload[:dispatched_at] > Time.now.to_f - 100
