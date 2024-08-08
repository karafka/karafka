# frozen_string_literal: true

# When eof is in use we may not get it as it may go with messages polling via `#consume`
# It may happen that eof goes via `#eofed` because of polling but we will correct this spec only
# when this would happen as it should not be frequent

setup_karafka do |config|
  config.kafka[:'enable.partition.eof'] = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:eofed] = eofed?
  end

  def eofed
    raise
  end

  def shutdown
    DT[:shutdown] = eofed?
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT.key?(:eofed)
end

assert DT[:eofed]
assert DT[:shutdown]
