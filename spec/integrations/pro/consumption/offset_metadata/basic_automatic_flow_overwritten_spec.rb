# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When offset metadata is stored but a custom forced value is used, the forced on should be used.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:'auto.commit.interval.ms'] = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.5)

    DT[:metadata] << offset_metadata(cache: false)

    store_offset_metadata(messages.first.offset.to_s)

    mark_as_consumed(messages.first, 'cs')
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management(true)
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:metadata].size >= 10
end

assert_equal DT[:metadata].uniq, ['', 'cs']
