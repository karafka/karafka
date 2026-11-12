# frozen_string_literal: true

# Karafka should use the defaults if they were configured but only if the appropriate config
# setup was not executed

setup_karafka

DefaultsConsumer = Class.new(Karafka::BaseConsumer)
TopicConsumer = Class.new(Karafka::BaseConsumer)

draw_routes(create_topics: false) do
  defaults do
    manual_offset_management false
    config(replication_factor: 2, partitions: 5)
    consumer DefaultsConsumer
    max_messages 50
    max_wait_time 500
    initial_offset "latest"
    consumer_persistence false
    kafka("bootstrap.servers": "defaults:9092")
  end

  subscription_group do
    topic "topic1" do
      consumer Class.new(Karafka::BaseConsumer)
      dead_letter_queue(topic: "xyz", max_retries: 2)
      manual_offset_management true
      config(replication_factor: 12, partitions: 15)
    end
  end

  topic "topic2" do
    consumer Class.new(Karafka::BaseConsumer)
  end

  topic "topic3" do
    consumer TopicConsumer
    max_messages 7
    max_wait_time 77
    initial_offset "earliest"
    consumer_persistence true
    kafka("bootstrap.servers": "topic:9092")
  end

  topic "topic4"
end

t1, t2, t3, t4 = Karafka::App.routes.first.topics.to_a

assert t1.dead_letter_queue?
assert t1.manual_offset_management?
assert_equal 12, t1.declaratives.replication_factor
assert_equal 15, t1.declaratives.partitions

assert !t2.dead_letter_queue?
assert !t2.manual_offset_management?
assert_equal 2, t2.declaratives.replication_factor
assert_equal 5, t2.declaratives.partitions

assert_equal TopicConsumer, t3.consumer
assert_equal 7, t3.max_messages
assert_equal 77, t3.max_wait_time
assert_equal "earliest", t3.initial_offset
assert_equal true, t3.consumer_persistence
assert_equal({ "bootstrap.servers": "topic:9092" }, t3.kafka)

assert_equal DefaultsConsumer, t4.consumer
assert_equal 50, t4.max_messages
assert_equal 500, t4.max_wait_time
assert_equal "latest", t4.initial_offset
assert_equal false, t4.consumer_persistence
assert_equal({ "bootstrap.servers": "defaults:9092" }, t4.kafka)
assert !t4.dead_letter_queue?
assert !t4.manual_offset_management?
assert_equal 2, t4.declaratives.replication_factor
assert_equal 5, t4.declaratives.partitions
