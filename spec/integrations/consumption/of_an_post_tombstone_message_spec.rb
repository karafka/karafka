# frozen_string_literal: true

# When consuming post-compaction data, it should not consume pre-compact info.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.payload
    end
  end
end

draw_routes do
  topic DT.topic do
    # Those are really aggressive settings to force Kafka into compaction
    config(
      partitions: 1,
      'max.compaction.lag.ms': 50_000,
      'retention.ms': 50_000,
      'delete.retention.ms': 100,
      'cleanup.policy': 'compact',
      'min.cleanable.dirty.ratio': 0.001,
      'segment.ms': 100,
      'segment.bytes': 100,
      'min.compaction.lag.ms': 10
    )
    consumer Consumer
  end
end

data = Array.new(2) { '1' }

5.times do
  produce_many(DT.topic, data, key: '1')
end

produce(DT.topic, nil, key: '1')
produce(DT.topic, '2', key: '1')

# We need to wait so Kafka does a compaction
# If this spec fails randomly, this will have to be extended
sleep(30)

start_karafka_and_wait_until do
  DT.key?(0)
end

assert_equal [nil, 2], DT[0]
