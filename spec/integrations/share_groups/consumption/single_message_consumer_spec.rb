# frozen_string_literal: true

# Share group (KIP-932) can be used with a custom "per message" consumer abstraction layer
# ("1.4 style"). With share groups each record is acknowledged on its own right after it is
# processed, so a failure of one record does not cause the redelivery of the already processed
# ones.

setup_karafka(allow_errors: %w[consumer.consume.error])

# Abstraction layer on top of Karafka to build "per message" share consumers
class SingleMessageBaseConsumer < Karafka::ShareConsumer
  attr_reader :message

  def consume
    messages.each do |message|
      @message = message
      consume_one
      mark_as_accepted(message)
    end
  end
end

class Consumer < SingleMessageBaseConsumer
  def consume_one
    DT[:deliveries] << [message.raw_payload, message.delivery_count]

    # Fail once in the middle of the stream
    raise StandardError if message.raw_payload == DT[:failing] && message.delivery_count == 1

    DT[message.partition] << message.raw_payload
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

elements = DT.uuids(20)
DT[:failing] = elements[10]
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

assert_equal elements.sort, DT[0].sort
assert_equal 20, DT[0].size
# Only the failing record (and the ones after it in its batch that were not processed yet) were
# delivered again. Records processed before the failure were not
elements.first(10).each do |payload|
  assert_equal 1, DT[:deliveries].count { |delivered, _| delivered == payload }
end
assert DT[:deliveries].include?([elements[10], 2])
