# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to multiplex a pattern and things should operate as expected

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:clients] << client.object_id
    DT[:consumers] << object_id
  end
end

draw_routes(create_topics: false) do
  subscription_group :sg do
    multiplexing(max: 5)

    pattern('test', /#{DT.topic}/) do
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until do
  unless @created
    sleep(5)

    Karafka::Admin.create_topic(
      DT.topic,
      10,
      1
    )
    @created = true
  end

  10.times do |i|
    produce_many(DT.topic, DT.uuids(10), partition: i)
  end

  sleep(1)

  DT[:clients].uniq.count >= 5 && DT[:consumers].uniq.count >= 5
end

assert_equal 5, DT[:clients].uniq.size
assert DT[:consumers].uniq.size >= 5
