# frozen_string_literal: true

# Kafka settings can be overridden per share group (KIP-932) topic, the same way as for consumer
# groups. Each share group should run its own share consumer with its own settings (here a
# distinct client.id and max.poll.records) while still consuming, and settings defined only for
# one group must not leak into the other one.

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
      kafka(
        "client.id": "custom-share-client",
        "max.poll.records": 5,
        inherit: true
      )
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

custom_sg = Karafka::App.routes.share_groups.first.subscription_groups.first
default_sg = Karafka::App.routes.share_groups.last.subscription_groups.first

# Overrides are applied on top of the inherited root settings
assert_equal "custom-share-client", custom_sg.kafka.fetch(:"client.id")
assert_equal 5, custom_sg.kafka.fetch(:"max.poll.records")
assert_equal DT.groups[0], custom_sg.kafka.fetch(:"group.id")
assert_equal(
  Karafka::App.config.kafka.fetch(:"bootstrap.servers"),
  custom_sg.kafka.fetch(:"bootstrap.servers")
)

# And they do not leak into the other share group
assert_equal Karafka::App.config.client_id, default_sg.kafka.fetch(:"client.id")
assert_not_equal 5, default_sg.kafka[:"max.poll.records"]

Karafka.monitor.subscribe("statistics.emitted") do |event|
  DT[:clients] << [event[:subscription_group_id], event[:statistics]["client_id"]]
end

elements0 = DT.uuids(20)
elements1 = DT.uuids(20)
produce_many(DT.topics[0], elements0)
produce_many(DT.topics[1], elements1)

start_karafka_and_wait_until do
  DT[DT.topics[0]].size >= 20 &&
    DT[DT.topics[1]].size >= 20 &&
    DT[:clients].map(&:first).uniq.size >= 2
end

assert_equal elements0.sort, DT[DT.topics[0]].sort
assert_equal elements1.sort, DT[DT.topics[1]].sort

clients = DT[:clients].uniq.to_h

assert_equal "custom-share-client", clients.fetch(custom_sg.id)
assert_equal Karafka::App.config.client_id, clients.fetch(default_sg.id)
