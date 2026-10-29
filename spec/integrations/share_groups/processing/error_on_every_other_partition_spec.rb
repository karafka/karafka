# frozen_string_literal: true

# Share group (KIP-932) errors are isolated per partition: when only partition 0 batches fail on
# their first delivery, records of other partitions are accepted once, while partition 0 records
# are released, redelivered and then accepted.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << [message.partition, message.raw_payload, message.delivery_count]
    end

    if messages.metadata.partition.zero? && messages.any? { |message| message.delivery_count == 1 }
      raise StandardError
    end

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

setup_share_group(DT.topic, DT.group, 4)

elements = {}

4.times do |partition|
  elements[partition] = DT.uuids(10)
  produce_many(DT.topic, elements[partition], partition: partition)
end

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 40
end

# Give the broker a chance to redeliver anything that was not settled
sleep(5)

assert_equal elements.values.flatten.sort, DT[:accepted].uniq.sort

elements.each do |partition, payloads|
  payloads.each do |payload|
    deliveries = DT[:deliveries].select { |_, delivered, _| delivered == payload }

    assert_equal [partition], deliveries.map(&:first).uniq

    counts = deliveries.map(&:last)

    if partition.zero?
      assert counts.include?(1)
      assert counts.max >= 2
    else
      assert_equal [1], counts
    end
  end
end
