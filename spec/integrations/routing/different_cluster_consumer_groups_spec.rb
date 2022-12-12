# frozen_string_literal: true

# Karafka should allow for defining separate consumer groups that will talk with separate clusters
# Distribution in subscription groups should match same cluster with same settings

setup_karafka

draw_routes do
  # Use default setup settings for Kafka, etc
  consumer_group :test1 do
    topic 'topic1' do
      kafka('bootstrap.servers': 'cluster1:9092')

      consumer Class.new
    end
  end

  consumer_group :test2 do
    topic 'topic1' do
      kafka('bootstrap.servers': 'cluster2:9092')

      consumer Class.new
    end

    topic 'topic2' do
      kafka('bootstrap.servers': 'cluster2:9092')

      consumer Class.new
    end
  end
end

subscription_groups = Karafka::App.subscription_groups.values.flatten

assert_equal 2, Karafka::App.routes.size
assert_equal 2, Karafka::App.consumer_groups.size
assert_equal 2, subscription_groups.size
assert_equal 1, Karafka::App.consumer_groups.first.topics.size
assert_equal 'topic1', Karafka::App.consumer_groups.first.topics.first.name
assert_equal 'topic1', Karafka::App.consumer_groups.last.topics[0].name
assert_equal 'topic2', Karafka::App.consumer_groups.last.topics[1].name

t1 = Karafka::App.consumer_groups.first.topics.first.kafka
t2 = Karafka::App.consumer_groups.last.topics.first.kafka
t3 = Karafka::App.consumer_groups.last.topics.last.kafka

assert t1 != t2
assert_equal t2, t3
