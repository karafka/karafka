# frozen_string_literal: true

# Karafka should be able to consume and web tracking should not interfere

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    p committed_offset_metadata
    mark_as_consumed!(messages.last, 'test')
    DT[:done] = true

    t = Time.now.to_f
    p offset_metadata(cache: false)
    p (Time.now.to_f - t) * 1000
    t = Time.now.to_f
    p offset_metadata
    p (Time.now.to_f - t) * 1000
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
