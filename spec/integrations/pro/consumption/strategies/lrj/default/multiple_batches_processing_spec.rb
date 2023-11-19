# frozen_string_literal: true

# When processing multiple incoming batches, the order should be preserved

setup_karafka do |config|
  config.max_messages = 10
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

# We want to sleep few times but not all the time not to exceed max execution time of specs
DT[:sleeps] = [
  true,
  false,
  false,
  false,
  true,
  false,
  true
]

class Consumer < Karafka::BaseConsumer
  def consume
    # Ensure we exceed max poll interval, if that happens and this would not work async we would
    # be kicked out of the group
    # Sleep from time to time
    sleep(11) if DT[:sleeps].pop

    messages.each do |message|
      DT[0] << message.offset
    end

    produce_many(DT.topic, DT.uuids(5))
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
    end
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[0].size >= 100
end

previous = nil

DT[0].each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset

  previous = offset
end
