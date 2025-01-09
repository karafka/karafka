# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Offset should move forward with metadata but because we cache result, it should not update
# in memory as there is no rebalance.

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed!(message, { offset: message.offset }.to_json)
      DT[:metadata] << offset_metadata.fetch('offset')
    end
  end
end

class JsonDeserializer
  def call(raw_metadata)
    JSON.parse(raw_metadata)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    offset_metadata(
      cache: true,
      deserializer: JsonDeserializer.new
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:metadata].size >= 100
end

assert_equal DT[:metadata], Array.new(100, 0)
