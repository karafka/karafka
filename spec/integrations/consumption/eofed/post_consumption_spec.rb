# frozen_string_literal: true

# When eof is in use we may not get it as it may go with messages polling via `#consume`
# It may happen that eof goes via `#eofed` because of polling but we will correct this spec only
# when this would happen as it should not be frequent

setup_karafka do |config|
  config.kafka[:'enable.partition.eof'] = true
  config.max_messages = 100
  config.max_wait_time = 30_000
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:eof] = eofed?
  end

  # This should never happen because we do not reach eof without messages
  def eofed
    raise
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    eofed true
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:eof] == true
end
