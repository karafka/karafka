# frozen_string_literal: true

# A case where we have 5 workers consuming data from 5 partitions in a pass-through mode
# This won't actually do much better than a single worker setup, due to how the default
# configuration for messages fetching works. It will most of the time fetch one partition data with
# a single poll operation. For parallel we have other cases that elevate IO. Here we are just
# interested in the raw number.

setup_karafka { |config| config.concurrency = 5 }

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

    if @count >= MAX_MESSAGES_PER_PARTITION
      DataCollector.data[:completed] << messages.metadata.partition
    end

    return if DataCollector.data[:completed].size != PARTITIONS_COUNT
    return if $stop

    $stop = Time.monotonic
    Thread.new { Karafka::Server.stop }
  end
end

draw_routes('benchmarks_00_05')

Tracker.run(messages_count: MAX_MESSAGES_PER_PARTITION * PARTITIONS_COUNT) do
  DataCollector.data[:completed] = Set.new
  $start = false
  $stop = false

  Karafka::Server.run

  $stop - $start
end

# Time taken: 7.386561989199936
# Messages per second: 67690.48993714013
