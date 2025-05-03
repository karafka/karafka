# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end
end

Thread.new do
  sleep(5)

  iteration = 0

  100.times do
    iteration += 1

    5.times do |round|
      enveloped = Karafka::Pro::ScheduledMessages.schedule(
        message: {
          topic: DT.topics[1],
          payload: {}.to_json, key: "#{5 - round}.seconds.ago.to_i-#{iteration}"
        },
        epoch: Time.now.to_i - (5 + round),
        envelope: {
          topic: DT.topics[0],
          key: "#{iteration}-#{Time.now.to_i}#{SecureRandom.uuid}",
          partition: 0
        }
      )

      Karafka.producer.produce_async(enveloped)
    end

    sleep(0.1)
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
  dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 500)

  dispatched.size >= 500
end

assert_equal dispatched.size, 500
