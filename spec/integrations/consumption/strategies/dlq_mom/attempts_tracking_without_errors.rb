# frozen_string_literal: true

# When running jobs without problems, there should always be only one attempt

setup_karafka do |config|
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:attempts] << coordinator.pause_tracker.attempt

    messages.each { |message| DT[0] << message.offset }
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
    manual_offset_management true
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 100
end

DT[:attempts].each { |attempt| assert_equal 1, attempt, DT[:attempts] }
