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

module Factory
  THROTTLERS = {}

  MUTEX = Mutex.new

  class << self
    def call(topic, partition)
      MUTEX.synchronize do
        THROTTLERS["#{topic.name}-#{partition}"] ||= begin
          # We set 10 seconds so we can trigger a rebalance and check that it still complies
          ::Karafka::Pro::Processing::Filters::Throttler.new(5, 10_000)
        end
      end
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    filter(Factory)
    manual_offset_management true
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

consumer = setup_rdkafka_consumer

thread = Thread.new do
  sleep(10)

  consumer.subscribe(DT.topic)

  consumer.each do
    break
  end
end

start_karafka_and_wait_until do
  DT[:offsets].count >= 10 && DT[:revoked].size.positive?
end

assert (DT[:times].last - DT[:revoked].first) >= 5

thread.join

consumer.close
