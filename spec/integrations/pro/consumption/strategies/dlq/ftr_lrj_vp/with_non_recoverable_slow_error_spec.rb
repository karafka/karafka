# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should be able to recover from non-critical error when using lrj the same way as any
# normal consumer and after few incidents it should move data to the DLQ and just continue

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep 15

    messages.each do |message|
      raise StandardError if messages.first.offset == 0

      DT[0] << message.offset
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[1] << message.headers['source_offset'].to_i
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    long_running_job true
    dead_letter_queue topic: DT.topics[1]
    throttling(limit: 5, interval: 5_000)
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
    throttling(limit: 5, interval: 5_000)
  end
end

produce_many(DT.topics[0], DT.uuids(5))

start_karafka_and_wait_until do
  !DT[1].empty?
end

assert_equal 4, DT[:errors].size
assert_equal 0, DT[1].first
assert_equal 1, DT[1].size
