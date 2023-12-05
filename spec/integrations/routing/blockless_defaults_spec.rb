# frozen_string_literal: true

# We should be able to set up a shared setup for topics and not use any block configuration
# This can be used for example to define routing for a separate app that only manages the topics
# states as a migrator app

setup_karafka

draw_routes do
  defaults do
    config(partitions: 5)
    active false
  end

  topic 'topic1'

  consumer_group :test do
    topic 'topic2'
  end
end

t1 = Karafka::App.consumer_groups.first.topics.first
t2 = Karafka::App.consumer_groups.last.topics.first

assert_equal 'topic1', t1.name
assert_equal 'topic2', t2.name

assert !t1.active?
assert !t2.active?

assert_equal 5, t1.config.partitions
assert_equal 5, t2.config.partitions
