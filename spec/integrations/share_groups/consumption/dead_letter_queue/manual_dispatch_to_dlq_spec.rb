# frozen_string_literal: true

# Share group (KIP-932) consumers with a DLQ defined can manually dispatch records to the DLQ topic
# (without raising any errors), for example upon detecting a corrupted record, and then reject
# them so they are not delivered again. The processing of the rest continues.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      if message.raw_payload == DT[:broken]
        dispatch_to_dlq(message)
        mark_as_rejected(message)
      else
        DT[:accepted] << message.raw_payload
        mark_as_accepted(message)
      end
    end
  end
end

class DlqConsumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:dlq] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 4)
    end

    topic DT.topics[1] do
      consumer DlqConsumer
    end
  end
end

setup_share_group(DT.topics[0])
setup_share_group(DT.topics[1])

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

elements = DT.uuids(10)
DT[:broken] = elements[0]
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[:dlq].any? && DT[:accepted].size >= 9 && sleep(2)
end

assert_equal [elements[0]], DT[:dlq]
assert_equal [elements[0]], DT[:dispatched]
assert_equal elements[1..].sort, DT[:accepted].sort
