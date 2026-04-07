# frozen_string_literal: true

# When eof is in use the eof indication may arrive either together with messages (detectable via
# `eofed?` in `#consume`) or separately via the `#eofed` callback on a subsequent poll.
# Both paths are valid and this spec verifies that `eofed?` is true in either case after all
# messages have been consumed.

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.max_messages = 100
  config.max_wait_time = 30_000
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:eof] = eofed?
  end

  def eofed
    DT[:eof] = eofed?
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
