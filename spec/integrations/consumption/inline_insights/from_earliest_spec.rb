# frozen_string_literal: true

# We should be able to get the insights and use them via the API when they are defined

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:stats] << statistics
    DT[:stats] << insights
    DT[:stats_exist] << statistics?
    DT[:stats_exist] << insights?
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    inline_insights(true)
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(10))

  DT.key?(:stats) && DT[:stats_exist].include?(true) && !DT[:stats].last.empty?
end

assert_equal 0, DT[:stats].last["partition"]
