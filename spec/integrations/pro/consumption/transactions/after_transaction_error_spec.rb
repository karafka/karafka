# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# If transaction finishes and the error is after it, it should not impact the offset nor the
# location where we retry

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.max_messages = 2
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    transaction do
      mark_as_consumed(messages.first, messages.first.offset.to_s)
    end

    if DT.key?(:raised)
      DT[:done] = true
    else
      DT[:raised] = true
      raise StandardError
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal 1, DT[:offsets].count(0)
