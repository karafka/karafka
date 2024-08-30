# frozen_string_literal: true

# When there are no messages at all, we should publish nothing except an empty state

setup_karafka

draw_routes do
  scheduled_messages(topics_namespace: DT.topic)
end

state = nil

start_karafka_and_wait_until do
  message = Karafka::Admin.read_topic("#{DT.topic}states", 0, 1).first

  unless message
    sleep(1)
    next false
  end

  state = message
end

assert_equal state.headers, { 'zlib' => 'true' }
assert_equal state.payload, {
  schema_version: '1.0.0',
  state: 'loaded',
  daily: { '2024-08-29': 0 }
}
