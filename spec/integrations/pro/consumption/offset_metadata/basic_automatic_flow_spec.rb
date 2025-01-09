# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should be able to take the offset from the `store_metadata_offset` invocation and use it

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:'auto.commit.interval.ms'] = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.5)

    DT[:metadata] << offset_metadata(cache: false)

    store_offset_metadata(messages.first.offset.to_s)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:metadata].size >= 10
end

assert_equal DT[:metadata], [''] + (0..8).to_a.map(&:to_s)
