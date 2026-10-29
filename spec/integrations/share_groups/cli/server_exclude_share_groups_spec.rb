# frozen_string_literal: true

# Running `karafka server --exclude-share-groups` should run everything except the excluded share
# group (KIP-932): the consumer group keeps consuming while the excluded share group does not
# acquire any records.

setup_karafka

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

elements = DT.uuids(10)
produce_many(DT.topics[0], elements)
produce_many(DT.topics[1], DT.uuids(10))

Thread.new do
  wait_until do
    DT[:consumer_group].size >= elements.size && sleep(2)
  end
end

ARGV.replace(["server", "--exclude-share-groups", DT.groups[1]])

Karafka::Cli.start

ARGV.clear

assert_equal elements, DT[:consumer_group]
assert_equal [], DT[:share_group]
