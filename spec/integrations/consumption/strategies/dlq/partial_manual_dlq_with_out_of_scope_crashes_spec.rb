# frozen_string_literal: true

# In case a manual DLQ dispatch is used on internal operations but the whole batch processing
# crashes, this can cause extensive reprocessing with small forward movement.
# Out of 100 messages produced, with this code we will end up with over a 1000 of failures because
# of how offsets are moving forward
#
# Note: This example illustrates a misuse of the DLQ flow and should not be used.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Simulate something went wrong on a per message basis
      raise StandardError
    rescue StandardError
      dispatch_to_dlq(message)
    end

    # Crash whole batch outside of per message error handling
    # It can be related to anything that happens outside of the per message operations but
    # inside of the iterator or after
    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message.raw_payload
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:broken].include?(elements.last)
end

# All DLQ dispatches should be based on dispatched data
assert((DT[:broken].uniq - elements).empty?)
