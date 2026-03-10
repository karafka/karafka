# frozen_string_literal: true

# When we do not have any offsets committed, `store_offsets` and `store_offsets!` should work
# as expected.
#
# `store_offsets!` can be useful in cases when we do want to delegate the offset management to
# Karafka but still want to make sure that upon consumption start we own the assignment. In such
# cases `store_offsets!` give us good knowledge of it.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:results] << commit_offsets
    DT[:results] << commit_offsets!
    DT[:done] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topics[0], DT.uuids(5))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal [true], DT[:results].uniq
