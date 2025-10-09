# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Upon non-recoverable errors, Karafka should move forward retrying from last one that was
# committed with duplicates in between comitted and crashed

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    mark_as_consumed(messages.first)

    messages.each do |message|
      raise StandardError if [1, 25].include?(message.offset)

      DT[0] << message.offset
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    long_running_job true
    dead_letter_queue topic: DT.topics[1], max_retries: 0
    manual_offset_management true
    throttling(limit: 5, interval: 5_000)
  end
end

produce_many(DT.topics[0], DT.uuids(50))

start_karafka_and_wait_until do
  DT[:errors].size >= 2 && DT[0].include?(49)
end

assert !DT[0].include?(1)
assert !DT[0].include?(25)
