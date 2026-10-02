# frozen_string_literal: true

# Share group (KIP-932) consumer that accepts part of a batch and then raises: the accepted records
# are never redelivered while the rest is released and comes back with a higher delivery count.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| DT[:deliveries] << [message.raw_payload, message.delivery_count] }

    fresh = messages.select { |message| message.delivery_count == 1 }

    # Redeliveries (and batches without fresh records) are accepted fully
    if fresh.empty?
      messages.each do |message|
        DT[:accepted] << message.raw_payload
        mark_as_accepted(message)
      end

      return
    end

    fresh.first(fresh.size / 2).each do |message|
      DT[:early] << message.raw_payload
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end

    raise StandardError
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
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 20
end

# Give the broker a chance to redeliver anything that was not settled
sleep(5)

assert_equal elements.sort, DT[:accepted].uniq.sort
assert !DT[:early].empty?

late = elements - DT[:early]

assert !late.empty?

DT[:early].each do |payload|
  counts = DT[:deliveries].select { |delivered, _| delivered == payload }.map(&:last)

  assert_equal [1], counts
end

late.each do |payload|
  counts = DT[:deliveries].select { |delivered, _| delivered == payload }.map(&:last)

  assert counts.include?(1)
  assert counts.max >= 2
end
