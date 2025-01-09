# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# With marking disabled, the rolling of error should not cause offset storage on errors

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 10
end

DT[:offsets] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset

      raise StandardError if message.offset >= 1

      mark_as_consumed(message)
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 1,
      mark_after_dispatch: false
    )
  end
end

produce_many(DT.topic, (0..10).to_a.map(&:to_s))

start_karafka_and_wait_until do
  DT[:offsets].size >= 10
end

assert_equal fetch_next_offset, 1
