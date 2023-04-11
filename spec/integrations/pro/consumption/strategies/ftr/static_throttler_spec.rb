# frozen_string_literal: true

# We should be able to use a factory, that always returns the same throttler even after
# rebalances, so throttling still applies after rebalance

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:times] << Time.now

    messages.each do |message|
      DT[:offsets] << message.offset
    end
  end

  def revoked
    DT[:revoked] << Time.now
  end
end

THROTTLERS = Concurrent::Map.new
FACTORY = ->(topic, partition) do
  THROTTLERS.compute_if_absent("#{topic.name}-#{partition}") do
    # We set 30 seconds so we can trigger a rebalance and check that it still complies
    ::Karafka::Pro::Processing::Filters::Throttler.new(5, 15_000)
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    filter(FACTORY)
    manual_offset_management true
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

Thread.new do
  sleep(5)

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)

  consumer.each do |message|
    break
  end

  consumer.close
end

start_karafka_and_wait_until do
  DT[:offsets].count >= 10 && DT[:revoked].size.positive?
end

assert (DT[:times].last - DT[:revoked].first) >= 5
