# frozen_string_literal: true

# Share group (KIP-932) consuming a larger volume without errors: every record is accepted and none
# is delivered more than once.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << message.delivery_count
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

elements = DT.uuids(5_000)
elements.each_slice(1_000) { |slice| produce_many(DT.topic, slice) }

start_karafka_and_wait_until do
  if DT[:accepted].size >= 5_000
    DT[:done_at] = Time.now unless DT.key?(:done_at)

    # Give the broker time to redeliver anything that was not accepted
    Time.now - DT[:done_at] > 5
  else
    false
  end
end

assert_equal 5_000, DT[:accepted].size
assert_equal elements.sort, DT[:accepted].sort
assert_equal [1], DT[:deliveries].uniq
