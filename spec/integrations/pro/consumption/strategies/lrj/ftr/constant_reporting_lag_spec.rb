# frozen_string_literal: true

# When using running with a delay and producing in a loop, we should always have a lag not bigger
# than the total of things that are in front of our marked offset
#
# If we run a non-blocking marking that happens less frequently than polling, this can go beyond
# what we currently process + what is ahead, because technically we are behind

PRODUCER = -> { produce_many(DT.topic, DT.uuids(5)) }

setup_karafka

statistics_events = []

Karafka::App.monitor.subscribe('statistics.emitted') do |event|
  statistics_events << event.payload
end

class Consumer < Karafka::BaseConsumer
  def consume
    PRODUCER.call
    mark_as_consumed!(messages.last)
    sleep(2)
  end
end

draw_routes do
  topic DT.topic do
    # Stress out LRJ to make sure it does not impact metrics in any way
    max_wait_time 200
    consumer Consumer
    delay_by(2_000)
    long_running_job
  end
end

PRODUCER.call

start_karafka_and_wait_until do
  sleep(30)
end

lags = Set.new

statistics_events.each do |event|
  lag = event[:statistics].dig('topics', DT.topic, 'partitions', '0', 'consumer_lag_stored')

  # Lag may not be present when first reporting happens before data processing
  next unless lag

  lags << lag
end

assert !lags.empty?

# Reported lag can equal to what we are processing + what we have ahead of us but should never
# exceed those values
assert lags.all? { |lag| lag <= 10 }, lags
