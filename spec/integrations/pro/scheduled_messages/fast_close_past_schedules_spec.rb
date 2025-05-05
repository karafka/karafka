# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Messages scheduled close in past should work without any issues

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
          payload: {}.to_json
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

dispatched = nil

start_karafka_and_wait_until(sleep: 1) do
  dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 500)

  dispatched.size >= 500
end

assert_equal 500, dispatched.size
