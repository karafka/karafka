# frozen_string_literal: true

# When eof is in use and we get it on an empty topic, we should not use consume and start with
# `#eofed`. Shutdown should also work and respond to `#eofed?`

setup_karafka do |config|
  config.kafka[:'enable.partition.eof'] = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def eofed
    DT[:eofed] = eofed?
  end

  def shutdown
    DT[:shutdown] = eofed?
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  DT.key?(:eofed)
end

assert DT[:eofed]
assert DT[:shutdown]
