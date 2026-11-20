# frozen_string_literal: true

# Karafka should support chaotic order group definitions and should correctly assign the
# subscription groups

setup_karafka

draw_routes(create_topics: false) do
  topic "topic0" do
    consumer Class.new(Karafka::BaseConsumer)
  end

  subscription_group "group1" do
    topic "topic1" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  consumer_group "test" do
    topic "topic1" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  topic "topic2" do
    consumer Class.new(Karafka::BaseConsumer)
  end
end

subscription_groups = Karafka::App.subscription_groups
default_group = subscription_groups.values.first

assert_equal 2, default_group.size
assert_equal %w[topic0 topic2], default_group.first.topics.map(&:name)
assert_equal %w[topic1], default_group.last.topics.map(&:name)
assert_equal 1, subscription_groups.values.last.size
