# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When insights are required, we should not proceed without them
# Because initial metrics fetch is slightly unpredictable (different with KRaft) and can be
# impacted by the cpu load, we simulate lack by patching the tracker so first first 10 seconds
# of running the process it returns no data

setup_karafka

module Patch
  include Karafka::Core::Helpers::Time

  def find(*args)
    @started_at ||= monotonic_now

    return {} if monotonic_now - @started_at < 10_000

    super
  end
end

Karafka::Processing::InlineInsights::Tracker.prepend(Patch)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:stats] << statistics
    DT[:stats] << insights
    DT[:stats_exist] << statistics?
    DT[:stats_exist] << insights?

    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    inline_insights(required: true)
  end
end

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:stats) &&
    DT[:stats_exist].include?(true) &&
    !DT[:stats].last.empty? &&
    DT[:offsets] == (0..9).to_a
end

assert_equal 0, DT[:stats].last['partition']
