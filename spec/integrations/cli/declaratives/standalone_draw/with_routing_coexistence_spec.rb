# frozen_string_literal: true

# Standalone declaratives.draw and routing config() should share the same repository.
# If both define the same topic name, routing's first-call-wins semantics apply.

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

# Define via standalone draw first
Karafka::App.declaratives.draw do
  topic DT.topics[0] do
    partitions 20
    replication_factor 1
  end
end

# Now define the same topic via routing — should get the same declaration object
draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer
    config(partitions: 99, replication_factor: 99)
  end
end

# Standalone draw was first, so its values win (||= semantics in routing bridge)
declaration = Karafka::App.declaratives.find_topic(DT.topics[0])
assert_equal 20, declaration.partitions
assert_equal 1, declaration.replication_factor

# Routing topic should reference the same declaration
routing_topic = Karafka::App.routes.first.topics.first
assert_equal declaration.object_id, routing_topic.declaratives.object_id
