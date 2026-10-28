# frozen_string_literal: true

# A case where we have a single worker consuming data from 5 partitions in a pass-through mode

setup_karafka { |config| config.concurrency = 1 }

MAX_MESSAGES_PER_PARTITION = 100_000

PARTITIONS_COUNT = 5

class Consumer < Karafka::BaseConsumer
  def initialize
    super
    $start ||= Time.monotonic
    @count = 0
  end

  def consume
    @count += messages.size

    DT.data[:completed] << messages.metadata.partition if @count >= MAX_MESSAGES_PER_PARTITION

    return if DT.data[:completed].size != PARTITIONS_COUNT
    return if $stop

    $stop = Time.monotonic
    Thread.new { Karafka::Server.stop }
  end
end

draw_routes("benchmarks_00_05")

Tracker.run(messages_count: MAX_MESSAGES_PER_PARTITION * PARTITIONS_COUNT) do
  DT.data[:completed] = Set.new
  $start = false
  $stop = false

  reset_karafka_state!
  Karafka::Server.run

  $stop - $start
end

# Time taken: 3.521369354100898
# Messages per second: 141990.21736180916
