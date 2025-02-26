# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Proper segment names and ids should be generated

setup_karafka

draw_routes(create_topics: false) do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 2,
      partitioner: ->(message) { message.key }
    )

    topic DT.topic do
      consumer Karafka::BaseConsumer
    end
  end
end

assert_equal 2, Karafka::App.routes.size
assert_equal 0, Karafka::App.routes.first.segment_id
assert_equal 1, Karafka::App.routes.last.segment_id

Karafka::App.routes.clear

draw_routes(create_topics: false) do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Karafka::BaseConsumer
    end
  end
end

assert_equal(1, Karafka::App.routes.size)
assert_equal(-1, Karafka::App.routes.first.segment_id)

Karafka::App.routes.clear
