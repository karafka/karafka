# frozen_string_literal: true

# When moving back to expired it should seek to -1 which is latest (upcoming)
# This is expected as all expired mean there is nothing except high watermark (-1/latest)

setup_karafka

Karafka::App.monitor.subscribe('consumer.consuming.seek') do |event|
  DT[:seeks] << event[:message].offset
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(1)
    seek(Time.now - 60_000)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer

    config(
      partitions: 1,
      'cleanup.policy': 'compact',
      'min.cleanable.dirty.ratio': 0.00001,
      'segment.ms': 500,
      'segment.bytes': 2800,
      'delete.retention.ms': 500,
      'min.compaction.lag.ms': 500,
      'retention.ms': 500
    )
  end
end

10.times do
  produce_many(DT.topic, DT.uuids(10), key: 'test')
  produce_many(DT.topic, Array.new(10) { nil }, key: 'test')
end

start_karafka_and_wait_until do
  DT[:seeks].count { |seek| seek == -1 } >= 1
end
