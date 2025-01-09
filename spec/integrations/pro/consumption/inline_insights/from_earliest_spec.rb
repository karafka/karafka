# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to get the insights and use them via the API when they are defined
# In Pro despite extra option, should behave same as in OSS when no forced required

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

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:stats) && DT[:stats_exist].include?(true) && !DT[:stats].last.empty?
end

assert_equal 0, DT[:stats].last['partition']
