# frozen_string_literal: true

# Share group (KIP-932) consumers should publish consumer.wrap and consumer.wrapped around the
# jobs they run, with the share consumer as the caller.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def wrap(action)
    DT[:wrapped_actions] << action
    yield
  end

  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

Karafka::App.monitor.subscribe("consumer.wrap") do |event|
  DT[:wrap] << event[:caller]
end

Karafka::App.monitor.subscribe("consumer.wrapped") do |event|
  DT[:wrapped] << event[:caller]
  DT[:times] << event[:time]
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:accepted].size >= 10
end

assert !DT[:wrap].empty?
assert_equal DT[:wrap].size, DT[:wrapped].size
assert_equal DT[:wrapped_actions].size, DT[:wrapped].size
assert(DT[:wrap].all?(Consumer))
assert(DT[:wrapped].all?(Consumer))
assert(DT[:times].all? { |time| time.is_a?(Numeric) })
assert DT[:wrapped_actions].include?(:consume)
assert DT[:wrapped_actions].include?(:shutdown)
