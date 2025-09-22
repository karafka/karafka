# frozen_string_literal: true

# With above settings it would never finish because would accumulate messages for so long
# Only if eof return works, will it finish fast enough
setup_karafka do |config|
  # Early exit
  config.kafka[:'enable.partition.eof'] = true
  config.max_wait_time = 1_000_000
  config.max_messages = 100_000
  config.shutdown_timeout = 1_000_001
  config.internal.swarm.node_report_timeout = 1_500_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:execution_mode] = Karafka::Server.execution_mode.to_sym
    DT[0] << true
  end
end

draw_routes(Consumer)

Thread.new do
  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(1)
  rescue WaterDrop::Errors::ProducerClosedError
    nil
  end
end

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal :standalone, DT[:execution_mode]
