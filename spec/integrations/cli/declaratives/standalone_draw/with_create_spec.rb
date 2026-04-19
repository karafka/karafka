# frozen_string_literal: true

# Standalone declaratives.draw should create topic declarations that the CLI can use
# when combined with routing (CLI still discovers topics via routing tree).
# This test verifies that standalone draw creates declarations in the repository and
# that those declarations are accessible alongside routing-based declarations.

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

# Define a topic via the new standalone declaratives DSL
Karafka::App.declaratives.draw do
  topic DT.topics[0] do
    partitions 2
    replication_factor 1
    config "cleanup.policy" => "delete"
  end
end

# Define a different topic via routing (old way)
draw_routes(create_topics: false) do
  topic DT.topics[1] do
    consumer Consumer
    config(partitions: 3)
  end
end

# Verify standalone declaration exists in the repository
standalone = Karafka::App.declaratives.find_topic(DT.topics[0])
assert !standalone.nil?
assert_equal 2, standalone.partitions
assert_equal 1, standalone.replication_factor
assert_equal({ "cleanup.policy": "delete" }, standalone.details)

# Verify routing-based declaration also exists in the repository
routed = Karafka::App.declaratives.find_topic(DT.topics[1])
assert !routed.nil?
assert_equal 3, routed.partitions

# Verify both are in active topics
active_names = Karafka::App.declaratives.topics.map(&:name)
assert active_names.include?(DT.topics[0])
assert active_names.include?(DT.topics[1])
