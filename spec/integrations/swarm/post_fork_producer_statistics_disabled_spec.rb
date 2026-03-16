# frozen_string_literal: true

# When statistics.interval.ms is set to 0 on the producer and we fork in swarm mode,
# the post-fork producer should inherit the statistics.interval.ms = 0 setting,
# ensuring statistics remain disabled after the fork.

setup_karafka do |config|
  config.swarm.nodes = 1
  config.kafka[:"statistics.interval.ms"] = 0
end

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    stats_interval = Karafka.producer.config.kafka[:"statistics.interval.ms"]

    WRITER.puts(stats_interval.to_s)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until(mode: :swarm) do
  result = READER.gets

  next false unless result

  DT[:statistics_interval_ms] = result.strip

  true
end

# The post-fork producer should have inherited statistics.interval.ms = 0
assert_equal "0", DT[:statistics_interval_ms]
