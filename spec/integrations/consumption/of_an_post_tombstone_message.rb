# frozen_string_literal: true

# When consuming post-compaction data, it should not consume pre-compact info.

setup_karafka

# Those are really aggressive settings to force Kafka into compaction
create_topic(
  partitions: 1,
  config: {
    'max.compaction.lag.ms': 50_000,
    'retention.ms': 50_000,
    'delete.retention.ms': 100,
    'cleanup.policy': 'compact',
    'min.cleanable.dirty.ratio': 0.001,
    'segment.ms': 100,
    'segment.bytes': 100,
    'min.compaction.lag.ms': 10
  }
)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.payload
    end
  end
end

draw_routes(Consumer)

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
  DT[0].size >= 1
end

assert_equal [nil, 2], DT[0]
