# frozen_string_literal: true

# When using manual offset management and not marking anything at all, we should not change
# offsets but we should keep moving forward in the processing.

setup_karafka do |config|
  config.max_messages = 5
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
      manual_offset_management true
    end
  end
end

payloads = DT.uuids(20)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

previous = -1

DT[0].each do |offset|
  assert_equal previous + 1, offset

  previous = offset
end

assert_equal 0, fetch_first_offset
