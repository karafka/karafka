# frozen_string_literal: true

# Manual seek per user request should super-seed the automatic LRJ movement.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << messages.first.offset

    seek(3)
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    long_running_job true
    manual_offset_management true
  end
end

produce_many(DT.topics[0], DT.uuids(10))

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal [0, 3], DT[0].uniq
