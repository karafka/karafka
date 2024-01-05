# frozen_string_literal: true

# We should be able to have part of topics with periodics in the same SG

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def tick
    DT[:ticks] << topic.name
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    periodic interval: 100
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  DT[:ticks].count >= 6
end

assert_equal 1, DT[:ticks].uniq.size
