# frozen_string_literal: true

# Share group (KIP-932) error recovery: when `#consume` raises, every record it did not
# acknowledge is released and redelivered (with a higher delivery count), and the group keeps
# consuming.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| DT[:deliveries] << [message.raw_payload, message.delivery_count] }

    raise StandardError if messages.any? { |message| message.delivery_count == 1 }

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
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

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 10
end

assert_equal elements.sort, DT[:accepted].uniq.sort

elements.each do |element|
  counts = DT[:deliveries].select { |payload, _| payload == element }.map(&:last)

  assert counts.include?(1)
  assert counts.max >= 2
end
