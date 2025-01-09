# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should retry over and over again same message if the error is not one of recognized

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 2
  config.max_messages = 10
end

Karafka.monitor.subscribe('error.occurred') do
  DT[:count] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    # Should never happen
    exit! 1
  end
end

class MessageStrategy
  def call(*_args)
    :retry
  end
end

draw_routes do
  pattern(/#{DT.topics[0]}/) do
    consumer Consumer

    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )

    dead_letter_queue(
      topic: DT.topics[1],
      independent: true,
      strategy: MessageStrategy.new
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:count].size >= 20
end

assert_equal 0, fetch_next_offset
