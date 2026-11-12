# frozen_string_literal: true

# One frozen kafka settings hash with inherit: true should be usable by many topics, directly and
# via defaults, without being changed, and each topic should inherit the root kafka settings

setup_karafka

Karafka::App.config.kafka[:"session.timeout.ms"] = 30_000

SHARED = { inherit: true, "fetch.wait.max.ms": 100 }.freeze

draw_routes(create_topics: false) do
  defaults do
    kafka(SHARED)
  end

  topic "topic1" do
    consumer Class.new(Karafka::BaseConsumer)
    kafka(SHARED)
  end

  topic "topic2" do
    consumer Class.new(Karafka::BaseConsumer)
    kafka(SHARED)
  end

  topic "topic3" do
    consumer Class.new(Karafka::BaseConsumer)
  end

  topic "topic4" do
    consumer Class.new(Karafka::BaseConsumer)
  end
end

assert_equal({ inherit: true, "fetch.wait.max.ms": 100 }, SHARED)

topics = Karafka::App.routes.first.topics

assert_equal %w[topic1 topic2 topic3 topic4], topics.map(&:name)

topics.each do |topic|
  assert_equal "127.0.0.1:9092", topic.kafka[:"bootstrap.servers"]
  assert_equal 30_000, topic.kafka[:"session.timeout.ms"]
  assert_equal 100, topic.kafka[:"fetch.wait.max.ms"]
  assert !topic.kafka.key?(:inherit)
end
