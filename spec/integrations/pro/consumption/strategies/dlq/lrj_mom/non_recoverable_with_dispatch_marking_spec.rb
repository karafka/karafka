# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Upon non-recoverable errors and the DLQ dispatch with marking, Karafka should mark

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
    messages.each do |message|
      raise StandardError if message.offset == 1 || !DT.key?(:errors)
      raise StandardError if message.offset == 25

      DT[0] << message.offset
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    long_running_job true
    dead_letter_queue topic: DT.topics[1], max_retries: 0, mark_after_dispatch: true
    manual_offset_management true
  end
end

produce_many(DT.topics[0], DT.uuids(50))

start_karafka_and_wait_until do
  DT[:errors].size >= 2 && DT[0].size >= 46 && DT[0].include?(49)
end

assert_equal fetch_next_offset, 26, fetch_next_offset
