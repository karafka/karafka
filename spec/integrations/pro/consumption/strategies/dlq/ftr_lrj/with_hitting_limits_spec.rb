# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should throttle and wait for the expected time period before continuing the processing

setup_karafka do |config|
  config.max_wait_time = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
      DT[:messages_times] << Time.now.to_f
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 1)
    long_running_job true
    throttling(
      limit: 5,
      interval: 5_000
    )
  end
end

Karafka.monitor.subscribe 'filtering.throttled' do
  DT[:times] << Time.now.to_f
end

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

# All consumption should work fine, just throttled
assert_equal elements, DT[0]

DT[:times].each_with_index do |slot, index|
  assert_equal(5 * (index + 1), DT[:messages_times].count { |time| time < slot })
end
