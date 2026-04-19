# frozen_string_literal: true

# Multiple standalone declaratives.draw calls should be additive

setup_karafka

Karafka::App.declaratives.draw do
  topic DT.topics[0] do
    partitions 5
  end
end

Karafka::App.declaratives.draw do
  topic DT.topics[1] do
    partitions 10
    config "retention.ms" => 604_800_000
  end
end

# Both topics should exist
active_topics = Karafka::App.declaratives.topics
assert_equal 2, active_topics.size

t0 = Karafka::App.declaratives.find_topic(DT.topics[0])
t1 = Karafka::App.declaratives.find_topic(DT.topics[1])

assert_equal 5, t0.partitions
assert_equal 10, t1.partitions
assert_equal({ "retention.ms": 604_800_000 }, t1.details)
