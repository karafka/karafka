# frozen_string_literal: true

# Share group (KIP-932) topic marked as `active false` is not consumed, while the other topic of
# the same share group is. A share group excluded via the activity manager is not consumed either.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[message.topic] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
    end

    topic DT.topics[1] do
      consumer Consumer
      active false
    end
  end

  share_group DT.groups[2] do
    topic DT.topics[2] do
      consumer Consumer
    end
  end
end

# Listen only on the first share group
Karafka::App
  .config
  .internal
  .routing
  .activity_manager
  .include(:share_groups, DT.group)

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)
setup_share_group(DT.topics[2], DT.groups[2])

elements = DT.uuids(10)

# We send same records to all the topics, but expect only one to be consumed
3.times { |index| produce_many(DT.topics[index], elements) }

start_karafka_and_wait_until do
  if DT[DT.topics[0]].size >= 10
    DT[:consumed_at] = Time.now unless DT.key?(:consumed_at)

    # Give the inactive topics a chance to be consumed (it should not)
    Time.now - DT[:consumed_at] > 5
  else
    false
  end
end

assert_equal elements.sort, DT[DT.topics[0]].sort
assert !DT.key?(DT.topics[1])
assert !DT.key?(DT.topics[2])
