# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should favour a manual pause over throttling and take appropriate action when the
# pause has expired. So if we've reached throttling threshold and paused, after the manual pause
# is over, we should pause and not process

# We also should not have any duplicates and processing should be smooth

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
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

elements = DT.uuids(100)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

assert_equal DT[0], (0...DT[0].size).to_a
