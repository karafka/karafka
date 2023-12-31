# frozen_string_literal: true

# When we mark as consumed everything, automatic marking should not overwrite the metadata

setup_karafka do |config|
  config.max_messages = 100
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(messages.first.offset / 10.to_f)

    messages.each do |message|
      DT[:messages] << message.offset
      mark_as_consumed!(message, message.offset.to_s)
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
    virtual_partitions(
      partitioner: ->(_msg) { DT[:iterator].next },
      offset_metadata_strategy: :exact
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:messages].size >= 100
end

assert_equal %w[99], DT[:metadata].uniq
