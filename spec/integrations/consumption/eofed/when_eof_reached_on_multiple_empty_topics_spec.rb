# frozen_string_literal: true

# When eof is in use and we get it on an empty topic, we should not use consume and start with
# `#eofed` per each partition and topic independently

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def eofed
    DT[:eofed] << [topic.name, partition, eofed?]
  end

  def shutdown
    DT[:shutdown] << [topic.name, partition, eofed?]
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    config(partitions: 5)
    eofed true
  end

  topic DT.topics[1] do
    consumer Consumer
    config(partitions: 5)
    eofed true
  end
end

start_karafka_and_wait_until do
  DT[:eofed].size >= 10
end

assert_equal DT[:eofed], DT[:eofed].uniq
assert_equal DT[:shutdown], DT[:shutdown].uniq
