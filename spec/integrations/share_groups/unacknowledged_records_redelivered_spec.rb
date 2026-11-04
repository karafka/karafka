# frozen_string_literal: true

# Share group (KIP-932) records that the consumer does not acknowledge are released once the batch
# is processed and get redelivered. Here nothing is acknowledged on the first delivery and
# everything is accepted on the redelivery.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << [message.raw_payload, message.delivery_count]

      next if message.delivery_count == 1

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
  assert counts.include?(2)
end
