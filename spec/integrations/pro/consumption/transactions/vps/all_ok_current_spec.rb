# frozen_string_literal: true

# When working with transactions if all success and the strategy is current, last should be picked

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:done] << object_id

    transaction do
      sleep(5) if messages.first.offset.zero?

      messages.each do |message|
        # Synchronize here ensures that we record the offset reference with marking
        synchronize do
          mark_as_consumed!(message, message.offset.to_s)
          DT[:last] << message.offset.to_s
        end
      end
    end
  end

  def shutdown
    DT[:metadata] << offset_metadata(cache: false)
  end
end

DT[:iterator] = (0..9).cycle

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter VpStabilizer
    offset_metadata(cache: false)
    virtual_partitions(
      partitioner: ->(_msg) { DT[:iterator].next },
      offset_metadata_strategy: :current
    )
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:done].uniq.size >= 10
end

last = DT[:last].last

assert_equal DT[:metadata].last, last
assert_equal fetch_first_offset, false
