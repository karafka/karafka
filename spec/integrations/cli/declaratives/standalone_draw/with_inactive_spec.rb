# frozen_string_literal: true

# Standalone declaratives.draw with active(false) should exclude topic from active list

setup_karafka

Karafka::App.declaratives.draw do
  topic DT.topics[0] do
    partitions 5
    active false
  end

  topic DT.topics[1] do
    partitions 10
  end
end

# Inactive topic should exist in repository but not in active topics
inactive = Karafka::App.declaratives.find_topic(DT.topics[0])
assert !inactive.nil?
assert !inactive.active?
assert_equal 5, inactive.partitions

# Active topic should be in the active topics list
active_topics = Karafka::App.declaratives.topics
assert_equal 1, active_topics.size
assert_equal DT.topics[1], active_topics.first.name
assert_equal 10, active_topics.first.partitions
