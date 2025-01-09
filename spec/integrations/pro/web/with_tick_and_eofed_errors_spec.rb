# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we use web-ui and error happens during eofed and tick when no offsets were marked as
# consumed, web UI should not fail. It used to fail because it was trying to extract offsets
# from not (yet) existing marking

setup_karafka(allow_errors: %w[consumer.tick.error consumer.eofed.error]) do |config|
  config.kafka[:'enable.partition.eof'] = true
end

setup_web

class Consumer < Karafka::BaseConsumer
  def consume; end

  def eofed
    DT[:eofed] = true

    raise
  end

  def tick
    DT[:tick] = true

    raise
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    periodic(interval: 100)
    eofed(true)
  end
end

start_karafka_and_wait_until do
  DT.key?(:eofed) && DT.key?(:tick)
end
