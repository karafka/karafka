# frozen_string_literal: true

# When enable.partition.eof is on but topic eofed is false, we should not run eofed

setup_karafka do |config|
  config.kafka[:'enable.partition.eof'] = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] = true
  end

  # This should never run because topic has `#eofed` set to false (default).
  def eofed
    raise
  end

  def shutdown
    DT[:shutdown] = eofed?
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    eofed false
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(1))

  sleep(5)

  DT.key?(:consumed)
end

assert DT[:shutdown]
