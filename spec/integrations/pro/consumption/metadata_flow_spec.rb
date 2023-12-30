# frozen_string_literal: true

# Karafka should be able to consume and web tracking should not interfere

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    p committed_offset_metadata(cached: true)
    mark_as_consumed!(messages.last, 'test')
    DT[:done] = true

    t = Time.now.to_f
    p committed_offset_metadata(cached: true)
    p (Time.now.to_f - t) * 1000
    t = Time.now.to_f
    p committed_offset_metadata(cached: false)
    p (Time.now.to_f - t) * 1000
  end

  def committed_offset_metadata(cached: true)
    return false if revoked?

    Karafka::Pro::Processing::OffsetMetadata::Fetcher.find(topic, partition, cached: cached)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end

  topic 'test' do
    active(false)
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:done)
end
