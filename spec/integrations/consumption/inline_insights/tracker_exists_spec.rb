# frozen_string_literal: true

# The inline insights tracker should report that it has statistics for a consumed partition once
# the consumer has insights for it

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    return unless insights?

    DT[:exists] << Karafka::Processing::ConsumerGroups::InlineInsights::Tracker.exists?(topic, partition)
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

  DT.key?(:exists)
end

assert_equal [true], DT[:exists].uniq
