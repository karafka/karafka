# frozen_string_literal: true

# Standalone declaratives.draw should support defaults that apply to all topics

setup_karafka

Karafka::App.declaratives.draw do
  defaults do
    partitions 5
    replication_factor 2
  end

  topic DT.topics[0] do
    partitions 10
  end

  topic DT.topics[1]
end

t0 = Karafka::App.declaratives.find_topic(DT.topics[0])
t1 = Karafka::App.declaratives.find_topic(DT.topics[1])

# Topic-specific value overrides default
assert_equal 10, t0.partitions
assert_equal 2, t0.replication_factor

# Default values apply when not overridden
assert_equal 5, t1.partitions
assert_equal 2, t1.replication_factor
