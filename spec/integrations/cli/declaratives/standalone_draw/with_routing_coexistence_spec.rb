# frozen_string_literal: true

# Standalone declaratives.draw and routing config() should share the same repository.
# Both populate the same Declaratives::Topic object. Routing config() always applies its
# values (it overwrites), so the last writer wins on the shared declaration.

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

# Now define topics[0] via routing — routing config() overwrites values on the shared object
draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer
    config(partitions: 99, replication_factor: 2)
  end
end

# Routing config() overwrote the shared declaration
declaration = Karafka::App.declaratives.find_topic(DT.topics[0])
assert_equal 99, declaration.partitions
assert_equal 2, declaration.replication_factor

# Routing topic and standalone draw share the same object
routing_topic = Karafka::App.routes.first.topics.first
assert_equal declaration.object_id, routing_topic.declaratives.object_id

# topics[1] was only defined via standalone draw, so its values are untouched
standalone_only = Karafka::App.declaratives.find_topic(DT.topics[1])
assert_equal 30, standalone_only.partitions
