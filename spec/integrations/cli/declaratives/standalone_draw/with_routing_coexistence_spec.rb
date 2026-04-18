# frozen_string_literal: true

# Standalone declaratives.draw and routing config() share the same repository.
# First declaration wins — if standalone draw defines a topic first, routing config()
# does not overwrite it (find_or_create_if_new semantics).

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

# Define via standalone draw first
Karafka::App.declaratives.draw do
  topic DT.topics[0] do
    partitions 20
    replication_factor 1
  end
end

# Define a different topic only via standalone draw (no routing counterpart)
Karafka::App.declaratives.draw do
  topic DT.topics[1] do
    partitions 30
  end
end

# Now define topics[0] via routing — routing config() should NOT overwrite because
# the declaration already exists from standalone draw
draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer
    config(partitions: 99, replication_factor: 2)
  end
end

# Standalone draw values are preserved (first writer wins)
declaration = Karafka::App.declaratives.find_topic(DT.topics[0])
assert_equal 20, declaration.partitions
assert_equal 1, declaration.replication_factor

# Routing topic references the same shared object
routing_topic = Karafka::App.routes.first.topics.first
assert_equal declaration.object_id, routing_topic.declaratives.object_id

# topics[1] was only defined via standalone draw, so its values are untouched
standalone_only = Karafka::App.declaratives.find_topic(DT.topics[1])
assert_equal 30, standalone_only.partitions
