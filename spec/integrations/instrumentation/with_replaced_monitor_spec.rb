# frozen_string_literal: true

# Karafka should allow for a monitor that can be used to run wrapped handling, as long as there is
# a delegation back to Karafka monitor afterwards.

DT[:tags] = Set.new

class WrappedMonitor < Karafka::Instrumentation::Monitor
  # Events we want to handle differently
  TRACEABLE_EVENTS = %w[
    consumer.consumed
  ].freeze

  def instrument(event_id, payload = EMPTY_HASH, &)
    # Always run super, so the default instrumentation pipeline works
    return super unless TRACEABLE_EVENTS.include?(event_id)

    DT[:tags] << :before

    super
  ensure
    DT[:tags].clear
  end
end

setup_karafka do |config|
  config.monitor = WrappedMonitor.new
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:inter_tags] = DT[:tags].dup
  end
end

draw_routes(Consumer)

produce(DT.topic, rand.to_s)

start_karafka_and_wait_until do
  DT.key?(:inter_tags)
end

assert DT[:tags].empty?
assert_equal DT[:inter_tags].to_a, %i[before]
