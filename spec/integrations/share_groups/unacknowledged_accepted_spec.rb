# frozen_string_literal: true

# Share group (KIP-932) topic configured with `acknowledgements(unacknowledged: :accept)`: records
# the consumer does not acknowledge itself are accepted after a successful consumption, so they are
# never redelivered.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| DT[:deliveries] << [message.raw_payload, message.delivery_count] }
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
      acknowledgements(unacknowledged: :accept)
    end
  end
end

setup_share_group

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  if DT[:deliveries].size >= 10
    DT[:all_seen_at] = Time.now unless DT.key?(:all_seen_at)

    # Give the broker time to redeliver anything that was not accepted
    Time.now - DT[:all_seen_at] > 5
  else
    false
  end
end

assert_equal elements.sort, DT[:deliveries].map(&:first).sort
assert(DT[:deliveries].all? { |_, count| count == 1 })
