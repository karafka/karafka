# frozen_string_literal: true

# When the consumers reporter switches to sync dispatch and it fails (for example times out
# because the brokers are unreachable), the failure should not abort the scheduler thread and with
# it the whole process

setup_karafka(allow_errors: true)

setup_web do |config|
  config.tracking.interval = 1_000
  # Report every dispatch in the sync mode
  config.tracking.consumers.sync_threshold = 1
end

# Swap the producer only after the migration, so only the tracking reports go to a broker that
# cannot be reached
Karafka::Web.config.producer = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = {
    "bootstrap.servers": "127.0.0.1:9",
    "message.timeout.ms": 1_000
  }
end

Karafka::Web.producer.monitor.subscribe("error.occurred") do |event|
  DT[:failures] << event[:error] if event[:type] == "messages.produce_many_sync"
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] = true
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT.key?(:consumed) && DT[:failures].size >= 3
end

assert DT[:failures].all? { |error| error.is_a?(WaterDrop::Errors::ProduceManyError) }
