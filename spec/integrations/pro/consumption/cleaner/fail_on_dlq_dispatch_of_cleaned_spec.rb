# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Attempt to dispatch to DLQ a cleaned message should always fail

setup_karafka(allow_errors: true)

Karafka.monitor.subscribe('error.occurred') do |event|
  DT[:errors] << event.payload[:error]
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      message.clean!

      raise if message.offset == 5

      mark_as_consumed(message)
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(
      topic: 'dead_messages',
      max_retries: 0
    )
  end
end

elements = DT.uuids(7).map { |val| { val: val }.to_json }
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:errors].size >= 2
end

# This error should be raised if DLQ dispatch attempt happens for cleaned message
assert DT[:errors].last.is_a?(Karafka::Pro::Cleaner::Errors::MessageCleanedError)
