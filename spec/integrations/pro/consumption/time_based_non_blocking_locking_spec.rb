# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to lock in a non-blocking fashion and then lock should expire based on time

setup_karafka do |config|
  config.max_messages = 1
  config.concurrency = 1
end

class Consumer1 < Karafka::BaseConsumer
  def consume
    subscription_groups_coordinator.pause(
      topic.subscription_group,
      1,
      timeout: 5_000
    )

    DT[0] << Time.now.to_f
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    DT[1] << Time.now.to_f
  end
end

draw_routes do
  subscription_group :a do
    topic DT.topics[0] do
      consumer Consumer1
    end
  end

  subscription_group :b do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

produce_many(DT.topics[0], DT.uuids(10))
produce_many(DT.topics[1], DT.uuids(10))

start_karafka_and_wait_until do
  DT[0].size >= 3 && DT[1].size >= 10
end
