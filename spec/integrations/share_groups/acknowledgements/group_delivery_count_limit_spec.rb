# frozen_string_literal: true

# Share group (KIP-932) with a per-group `share.delivery.count.limit` of 2: a record that always
# fails is delivered exactly twice and then dropped by the broker, while the rest is consumed.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    poison = false

    messages.each do |message|
      if message.raw_payload == "poison"
        poison = true
        DT[:poison] << message.delivery_count
      else
        DT[:accepted] << message.raw_payload
        mark_as_accepted(message)
      end
    end

    raise StandardError if poison
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group(configs: { "share.delivery.count.limit" => "2" })

elements = DT.uuids(10)
produce_many(DT.topic, elements.first(5) + ["poison"] + elements.last(5))

start_karafka_and_wait_until do
  if DT[:poison].size >= 2 && DT[:accepted].uniq.size >= 10
    DT[:exhausted_at] = Time.now unless DT.key?(:exhausted_at)

    # Make sure the broker does not deliver it again after the limit
    Time.now - DT[:exhausted_at] > 5
  else
    false
  end
end

assert_equal [1, 2], DT[:poison]
assert_equal elements.sort, DT[:accepted].uniq.sort
