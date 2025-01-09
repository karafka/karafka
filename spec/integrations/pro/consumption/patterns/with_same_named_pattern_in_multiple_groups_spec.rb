# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should work as expected when having same matching used in multiple CGs.

setup_karafka do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

class Consumer1 < Karafka::BaseConsumer
  def consume
    DT[0] = 1
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    DT[1] = 2
  end
end

draw_routes(create_topics: false) do
  pattern(:a, /#{DT.topic}/) do
    consumer Consumer1
  end

  consumer_group :b do
    pattern(:b, /#{DT.topic}/) do
      consumer Consumer2
    end
  end
end

start_karafka_and_wait_until do
  unless @created
    sleep(5)
    produce_many(DT.topic, DT.uuids(1))
    @created = true
  end

  DT.key?(0) && DT.key?(1)
end

assert_equal 1, DT[0]
assert_equal 2, DT[1]
