# frozen_string_literal: true

# Karafka should not build separate SGs when altering pause settings per topic in a SG/CG
# We also should be able to use any of the pause declaration styles.

setup_karafka

draw_routes(create_topics: false) do
  topic 'topic1' do
    consumer Class.new
    pause_timeout 100
    pause_max_timeout 1_000
    pause_with_exponential_backoff true
  end

  topic 'topic2' do
    consumer Class.new
    pause(
      timeout: 200,
      max_timeout: 2_000,
      with_exponential_backoff: false
    )
  end
end

t1 = Karafka::App.consumer_groups.first.topics.first
t2 = Karafka::App.consumer_groups.first.topics.last

assert_equal t1.subscription_group, t2.subscription_group

assert_equal t1.pause_timeout, 100
assert_equal t1.pause_max_timeout, 1_000
assert_equal t1.pause_with_exponential_backoff, true

assert_equal t2.pause_timeout, 200
assert_equal t2.pause_max_timeout, 2_000
assert_equal t2.pause_with_exponential_backoff, false
