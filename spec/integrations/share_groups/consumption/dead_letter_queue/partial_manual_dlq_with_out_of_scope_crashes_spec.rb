# frozen_string_literal: true

# Share group (KIP-932) consumer that manually dispatches every failing record to the DLQ (and
# rejects it) but then crashes the whole batch outside of the per record error handling. Unlike
# consumer groups (where offsets move forward slowly and the same records are dispatched over and
# over again), every record is acknowledged on its own, so the already rejected records are not
# delivered again and each record lands in the DLQ exactly once.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 100
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << message.raw_payload

      # Simulate something went wrong on a per message basis
      raise StandardError
    rescue
      dispatch_to_dlq(message)
      mark_as_rejected(message)
    end

    # Crash the whole batch outside of the per message error handling
    raise StandardError
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 0)
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

elements = DT.uuids(100)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[:dispatched].size >= 100 && sleep(2)
end

assert_equal elements.sort, DT[:dispatched].sort
assert_equal elements.sort, DT[:deliveries].sort
assert_equal(
  elements.sort,
  Karafka::Admin.read_topic(DT.topics[1], 0, 200).map(&:raw_payload).sort
)
