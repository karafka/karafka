# frozen_string_literal: true

# A simple case where we mark each message as consumed and move forward. We are interested here
# only in how long per message it takes to mark it as consumed in the sync mode

# Round-trips to Kafka are expensive and in general not recommended per message.

setup_karafka { |config| config.concurrency = 1 }

MAX_MESSAGES = 100_000

$times = []

class Consumer < Karafka::BaseConsumer
  def consume
    @count ||= 0
    @count += messages.size

    messages.each do |message|
      start = Time.now
      mark_as_consumed!(message)
      stop = Time.now

      $times << stop - start
    end

    return if @count < MAX_MESSAGES
    return if $stop

    Thread.new { Karafka::Server.stop }
  end
end

draw_routes('benchmarks_00_01')

Tracker.run(messages_count: MAX_MESSAGES) do
  Karafka::App.config.internal.status.reset!
  Karafka::Server.run

  $times.sum
end

# Time taken: 16.43162835
# Messages per second: 6085.824111278661
