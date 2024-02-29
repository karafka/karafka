# frozen_string_literal: true

# When altering the default pausing, it should not impact other topics

setup_karafka

draw_routes(create_topics: false) do
  topic :a do
    consumer Class.new(Karafka::BaseConsumer)
    pause(
      timeout: 1_000,
      max_timeout: 5_000,
      with_exponential_backoff: true
    )
  end

  topic :b do
    consumer Class.new(Karafka::BaseConsumer)
    pause(
      timeout: 5_000,
      max_timeout: 10_000,
      with_exponential_backoff: false
    )
  end

  topic :c do
    consumer Class.new(Karafka::BaseConsumer)
  end
end

topics = Karafka::App.routes.first.topics

assert_equal 1_000, topics[0].pause_timeout
assert_equal 5_000, topics[0].pause_max_timeout
assert_equal true, topics[0].pause_with_exponential_backoff

assert_equal 5_000, topics[1].pause_timeout
assert_equal 10_000, topics[1].pause_max_timeout
assert_equal false, topics[1].pause_with_exponential_backoff

assert_equal 1, topics[2].pause_timeout
assert_equal 1, topics[2].pause_max_timeout
assert_equal false, topics[2].pause_with_exponential_backoff
