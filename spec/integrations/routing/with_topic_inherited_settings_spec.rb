# frozen_string_literal: true

# We should be able to define defaults and then use the inherit flag to get per topic Kafka
# scope reconfiguration

setup_karafka

draw_routes(create_topics: false) do
  topic "topic1" do
    consumer Class.new
    kafka(
      "enable.partition.eof": true,
      inherit: true
    )
  end

  topic "topic2" do
    consumer Class.new
  end

  topic "topic4" do
    consumer Class.new
    kafka(
      "enable.partition.eof": true,
      inherit: true
    )
  end
end

cgs = Karafka::App.consumer_groups

assert_equal 1, cgs.size
# First and last topic setup should go to one SG
assert_equal 2, cgs.first.subscription_groups.size
# Merged sg should have expected topics
assert_equal %w[topic1 topic4], cgs.first.subscription_groups.first.topics.map(&:name)
# Merged topics should have defaults in them
t1k = cgs.first.subscription_groups.first.topics[0].kafka
t2k = cgs.first.subscription_groups.first.topics[1].kafka

assert_equal "127.0.0.1:9092", t1k[:"bootstrap.servers"]
assert_equal true, t1k[:"enable.partition.eof"]
assert_equal "127.0.0.1:9092", t2k[:"bootstrap.servers"]
assert_equal true, t2k[:"enable.partition.eof"]

# The merged SG should have the alterations
t1sg = cgs.first.subscription_groups.first.kafka
assert_equal "127.0.0.1:9092", t1sg[:"bootstrap.servers"]
assert_equal true, t1sg[:"enable.partition.eof"]
