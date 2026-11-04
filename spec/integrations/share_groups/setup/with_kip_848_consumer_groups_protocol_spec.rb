# frozen_string_literal: true

# When the global kafka scope uses the KIP-848 consumer group protocol (`group.protocol: consumer`)
# for consumer groups, share groups (KIP-932) defined in the same application should still work
# and consume alongside the consumer group.

setup_karafka(consumer_group_protocol: true)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:consumer_group] << message.raw_payload }
  end
end

class ShareConsumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:share_group] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes do
  consumer_group DT.groups[0] do
    topic DT.topics[0] do
      consumer Consumer
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.groups[1] do
    topic DT.topics[1] do
      consumer ShareConsumer
    end
  end
end

setup_share_group(DT.topics[1], DT.groups[1])

cg_elements = DT.uuids(10)
sg_elements = DT.uuids(10)
produce_many(DT.topics[0], cg_elements)
produce_many(DT.topics[1], sg_elements)

start_karafka_and_wait_until do
  DT[:consumer_group].size >= 10 && DT[:share_group].size >= 10
end

assert_equal cg_elements, DT[:consumer_group]
assert_equal sg_elements.sort, DT[:share_group].sort
