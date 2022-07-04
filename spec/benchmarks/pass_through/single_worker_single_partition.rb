# frozen_string_literal: true

# A simple case where we just measure how long does it take to pass through 100 000 messages
# from a single partition of a single topic.

setup_karafka { |config| config.concurrency = 1 }

# After how many messages should we stop
MAX_MESSAGES = 100_000

class Consumer < Karafka::BaseConsumer
  def initialize
    super
    $start ||= Time.monotonic
    @count = 0
  end

  def consume
    @count += messages.size

    return if @count < MAX_MESSAGES
    return if $stop

    $stop = Time.monotonic
    Thread.new { Karafka::Server.stop }
  end
end

draw_routes('benchmarks_00_01')

Tracker.run(messages_count: MAX_MESSAGES) do
  $start = false
  $stop = false

  Karafka::Server.run
  $stop - $start
end

# Time taken: 1.1387533107539638
# Messages per second: 87815.33195612878
