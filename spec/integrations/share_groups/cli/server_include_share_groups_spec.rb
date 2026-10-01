# frozen_string_literal: true

# Running `karafka server --include-share-groups` should only run the selected share group
# (KIP-932). Records of the topic consumed by the not-included share group must not be acquired by
# this process.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[topic.name] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.groups[0] do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  share_group DT.groups[1] do
    topic DT.topics[1] do
      consumer Consumer
    end
  end
end

setup_share_group(DT.topics[0], DT.groups[0])
setup_share_group(DT.topics[1], DT.groups[1])

elements = DT.uuids(10)
produce_many(DT.topics[0], elements)
produce_many(DT.topics[1], DT.uuids(10))

Thread.new do
  wait_until do
    # Give the excluded group a chance to (wrongly) pick up work
    DT[DT.topics[0]].size >= elements.size && sleep(2)
  end
end

ARGV.replace(["server", "--include-share-groups", DT.groups[0]])

Karafka::Cli.start

ARGV.clear

assert_equal elements.sort, DT[DT.topics[0]].sort
assert_equal [], DT[DT.topics[1]]
assert !Karafka::App.routes.share_groups.last.active?
