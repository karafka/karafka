# frozen_string_literal: true

# Karafka should allow to use the '.routes' alias for routing builder and it should support a case
# where there is a single consumer group with multiple topics

setup_karafka

draw_routes(create_topics: false) do
  topic 'topic1' do
    consumer Class.new
  end

  topic 'topic2' do
    consumer Class.new
  end

  topic 'topic3' do
    consumer Class.new
  end
end

assert_equal 1, Karafka::App.routes.size
assert_equal 1, Karafka::App.consumer_groups.size
assert_equal 1, Karafka::App.subscription_groups.size
assert_equal 3, Karafka::App.consumer_groups.first.topics.size
assert_equal 'topic1', Karafka::App.consumer_groups.first.topics.first.name
assert_equal 'topic2', Karafka::App.consumer_groups.first.topics[1].name
assert_equal 'topic3', Karafka::App.consumer_groups.first.topics[2].name

# Re-running simple routing should just add more topics

draw_routes(create_topics: false) do
  topic 'topic4' do
    consumer Class.new
  end

  topic 'topic5' do
    consumer Class.new
  end

  topic 'topic6' do
    consumer Class.new
  end
end

assert_equal 1, Karafka::App.routes.size
assert_equal 1, Karafka::App.consumer_groups.size
assert_equal 1, Karafka::App.subscription_groups.size
assert_equal 6, Karafka::App.consumer_groups.first.topics.size
assert_equal 'topic4', Karafka::App.consumer_groups.first.topics[3].name
assert_equal 'topic5', Karafka::App.consumer_groups.first.topics[4].name
assert_equal 'topic6', Karafka::App.consumer_groups.first.topics[5].name
