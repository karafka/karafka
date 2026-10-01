# frozen_string_literal: true

# Share group (KIP-932) records are delivered to every share group subscribed to a topic: two
# share groups on the same topic each get (and accept) all the records.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[topic.group.name] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.groups[0] do
    topic DT.topic do
      consumer Consumer
    end
  end

  share_group DT.groups[1] do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group(DT.topic, DT.groups[0])
# `share.auto.offset.reset` is a group level setting, so we point the second share group at the
# earliest record using a helper topic, as the main one already exists
setup_share_group(DT.topics[1], DT.groups[1])

elements = DT.uuids(50)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[DT.groups[0]].size >= 50 && DT[DT.groups[1]].size >= 50
end

assert_equal elements.sort, DT[DT.groups[0]].sort
assert_equal elements.sort, DT[DT.groups[1]].sort
