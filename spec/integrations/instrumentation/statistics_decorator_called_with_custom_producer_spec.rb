# frozen_string_literal: true

# When a custom producer has statistics.interval.ms NOT disabled (not set to 0),
# Karafka::Core::Monitoring::StatisticsDecorator#diff should be called when statistics
# are emitted.

setup_karafka do |config|
  # Disable statistics on the consumer side so we only track producer decorator calls
  config.kafka[:"statistics.interval.ms"] = 0
end

# Track if the decorator's diff method is ever called
ORIGINAL_DIFF = Karafka::Core::Monitoring::StatisticsDecorator.instance_method(:diff)

Karafka::Core::Monitoring::StatisticsDecorator.define_method(:diff) do |*args|
  DT[:diff_called] << true
  ORIGINAL_DIFF.bind_call(self, *args)
end

# Create a custom producer with statistics enabled
CUSTOM_PRODUCER = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  producer_config.kafka[:"statistics.interval.ms"] = 100
  producer_config.logger = Karafka::App.config.logger
end

# Subscribe a listener so the WaterDrop statistics callback does not skip due to no listeners
CUSTOM_PRODUCER.monitor.subscribe("statistics.emitted") do |event|
  DT[:producer_stats] << event
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end

    # Use the custom producer to produce a message, keeping it alive and emitting stats
    CUSTOM_PRODUCER.produce_sync(topic: DT.topic, payload: "from-custom-producer")
  end
end

draw_routes(Consumer)

elements = DT.uuids(5)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:diff_called].size >= 1
end

# The custom producer with statistics enabled should have triggered diff calls
assert DT[:diff_called].size >= 1

CUSTOM_PRODUCER.close
