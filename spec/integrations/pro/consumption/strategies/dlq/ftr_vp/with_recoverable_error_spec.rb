# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Errors should be handled normally. There should be a backoff and retry and recovery should start
# from the message on which we broke. Throttling should have nothing to do with this. The message
# should not go to the DLQ because the error has recovered.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset

      next unless message.offset == 7 && DT[:raised].empty?

      DT[:raised] << true

      raise StandardError, 'failure'
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consumer
    DT[:dlqed] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 5)
    throttling(
      limit: 5,
      interval: 2_000
    )
    virtual_partitions(
      partitioner: ->(message) { rand(message.offset) }
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 21
end

assert DT[:dlqed].empty?
assert((DT[0].count { |offset| offset == 7 }) >= 2)
