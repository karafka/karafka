# frozen_string_literal: true

setup_karafka { |config| config.concurrency = 1 }

MAX_MESSAGES = 100_000

$times = []

class Consumer < Karafka::BaseConsumer
  def consume
    @count ||= 0
    @count += messages.size

    messages.each do
      start = Time.now
      revoked?
      stop = Time.now

      $times << (stop - start)
    end

    return if @count < MAX_MESSAGES
    return if $stop

    Thread.new { Karafka::Server.stop }
  end
end

draw_routes("benchmarks_00_01")

Tracker.run(messages_count: MAX_MESSAGES) do
  reset_karafka_state!
  Karafka::Server.run

  $times.sum
end

# Time taken: 0.097942081
# Messages per second: 1021011.5915343886
