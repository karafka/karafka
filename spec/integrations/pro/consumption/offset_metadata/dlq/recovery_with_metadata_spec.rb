# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When stored metadata exists, it should be used in the DLQ flow.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
  config.kafka[:'auto.commit.interval.ms'] = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:metadata] << offset_metadata(cache: false)

    store_offset_metadata(messages.first.offset.to_s)

    raise StandardError
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer

    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 2
    )
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:metadata].size >= 10
end

assert_equal DT[:metadata][0..9], ['', '', '', 0, 0, 0, 1, 1, 1, 2].map(&:to_s)
