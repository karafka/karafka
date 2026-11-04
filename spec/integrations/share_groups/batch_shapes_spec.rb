# frozen_string_literal: true

# Share group (KIP-932) handles single record batches as well as batches terminated early: records
# the consumer did not get to (and did not acknowledge) after an early return are released and
# redelivered, so nothing is lost.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:batch_sizes] << messages.size

    messages.each do |message|
      data = JSON.parse(message.raw_payload)

      # Terminate early the first time we see this record, leaving the rest unacknowledged
      if data["terminate_early"] && message.delivery_count == 1
        DT[:terminated] << data["id"]

        return
      end

      DT[:processed] << [data["id"], message.delivery_count]
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

single = Array.new(5) { |i| { id: "single_#{i}", terminate_early: false }.to_json }
batch = Array.new(5) { |i| { id: "batch_#{i}", terminate_early: i == 2 }.to_json }
ids = (single + batch).map { |payload| JSON.parse(payload)["id"] }

produced = 0

start_karafka_and_wait_until do
  # Single record batches first, one at a time once the previous one was consumed
  if produced < 5 && DT[:processed].size == produced
    produce(DT.topic, single[produced])
    produced += 1
  elsif produced == 5 && DT[:processed].size == 5
    produce_many(DT.topic, batch)
    produced += 1
  end

  DT[:processed].map(&:first).uniq.size >= ids.size
end

assert_equal ids.sort, DT[:processed].map(&:first).uniq.sort
assert_equal [1, 1, 1, 1, 1], DT[:batch_sizes].first(5)
assert_equal ["batch_2"], DT[:terminated]

# Records processed before the early termination were accepted and not redelivered, while the
# terminating one and the ones after it were redelivered
DT[:processed].each do |id, delivery_count|
  expected = %w[batch_2 batch_3 batch_4].include?(id) ? 2 : 1

  assert_equal expected, delivery_count, [id, delivery_count]
end
