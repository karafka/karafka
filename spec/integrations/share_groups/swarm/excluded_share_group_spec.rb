# frozen_string_literal: true

# Share groups (KIP-932) cannot run in the swarm yet, but excluding them (as with
# `--exclude-share-groups`) must let the rest of the application run in the swarm: the supervisor
# must not fail fast on an excluded share group and the consumer group work is consumed by the
# forked nodes.

setup_karafka

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| WRITER.puts(message.raw_payload) }
  end
end

class ShareConsumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }
  end
end

draw_routes do
  consumer_group DT.groups[1] do
    topic DT.topic do
      consumer Consumer
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.groups[2] do
    topic DT.topics[1] do
      consumer ShareConsumer
    end
  end
end

Karafka::App.config.internal.routing.activity_manager.exclude(:share_groups, DT.groups[2])

elements = DT.uuids(10)
produce_many(DT.topic, elements)

received = []

start_karafka_and_wait_until(mode: :swarm) do
  received << READER.gets.strip

  received.size >= elements.size
end

assert_equal elements.sort, received.sort
