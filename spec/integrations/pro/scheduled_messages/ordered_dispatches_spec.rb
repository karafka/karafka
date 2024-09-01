# frozen_string_literal: true

# Messages going to one partition from one schedule topic partition should be always dispatched
# in order

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end
end

schedules = Array.new(50) do |i|
  message = {
    topic: DT.topics[1],
    key: i.to_s,
    headers: { 'b' => i.to_s },
    payload: "payload#{i}"
  }

  Karafka::Pro::ScheduledMessages.schedule(
    message: message,
    epoch: Time.now.to_i + 1,
    envelope: { topic: DT.topics[0], partition: 0 }
  )
end

Karafka.producer.produce_many_sync(schedules)

dispatched = nil

start_karafka_and_wait_until(sleep: 1) do
  dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 100)

  dispatched.size >= 50
end

assert_equal dispatched.map(&:key), (0..49).map(&:to_s)
