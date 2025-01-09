# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# In case transactional offset dispatch on post-error happens, Karafka should retry processing
# again and again.

setup_karafka(
  allow_errors: %w[consumer.consume.error consumer.after_consume.error]
) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

module Patch
  # We overwrite it to simulate a transactional error on the potential DLQ dispatch
  def transaction(*_args)
    raise StandardError
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless @enriched
      singleton_class.prepend Patch
      @enriched = true
    end

    DT[:offsets] << messages.first.offset

    raise StandardError
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 2,
      transactional: true
    )
  end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'consumer.consume.error'

  DT[:errors] << 1
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:errors].size >= 10
end

assert_equal DT[:offsets].uniq, [0]
