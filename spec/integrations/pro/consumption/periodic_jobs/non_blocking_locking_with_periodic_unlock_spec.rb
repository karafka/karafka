# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to lock in a non-blocking fashion our subscription group (or any other)
# and resume it from a periodic job on a different group
#
# Note: since we do not run periodics on the same go as a job, we cannot unlock from the same
# group. Time based locks are a different case covered in a different spec.

setup_karafka do |config|
  config.max_messages = 1
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT[1].size >= 10
      DT[:locks] << true

      subscription_groups_coordinator.pause(
        topic.subscription_group
      )

      DT[:group] = topic.subscription_group
    end

    DT[0] << Time.now.to_f
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    DT[1] << Time.now.to_f
  end

  def tick
    return unless DT[1].size >= 10
    return unless DT.key?(:group)
    return if @unlocked

    subscription_groups_coordinator.resume(DT[:group])
    @unlocked = true
  end
end

draw_routes do
  subscription_group :a do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  subscription_group :b do
    topic DT.topics[1] do
      consumer Consumer2
      periodic true
    end
  end
end

produce_many(DT.topics[0], DT.uuids(10))
produce_many(DT.topics[1], DT.uuids(10))

start_karafka_and_wait_until do
  DT[0].size >= 10 && DT[1].size >= 10
end

# All events except the first one should come after all events from the second topic
DT[1..].each do |time|
  assert time > DT[1].last
end
