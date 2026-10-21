# frozen_string_literal: true

# Share group (KIP-932) dead letter queue when the consumer accepts nothing until the end of a
# batch and a broken record crashes it: every record of the failed batch is released and retried.
# Once retries are exhausted, the records of the batch that were not accepted are moved to the DLQ
# (and rejected), which may include healthy ones that shared the batch with the broken record.
# Nothing is lost: each record is either accepted or in the DLQ, and the broken one always ends up
# in the DLQ.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.raw_payload == DT[:broken]
    end

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 1)
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

elements = DT.uuids(10)
DT[:broken] = elements[5]
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  (DT[:accepted] + DT[:dispatched]).uniq.size >= 10 && sleep(2)
end

assert DT[:dispatched].include?(elements[5])
assert !DT[:accepted].include?(elements[5])
# Each record is either accepted or dispatched, exactly once
assert_equal elements.sort, (DT[:accepted] + DT[:dispatched]).sort
assert_equal(
  DT[:dispatched].sort,
  Karafka::Admin.read_topic(DT.topics[1], 0, 20).map(&:raw_payload).sort
)
