# frozen_string_literal: true

# Karafka should allow for subscription groups definition without a name (auto-generated)

setup_karafka

draw_routes do
  subscription_group do
    topic 'topic1' do
      consumer Class.new
    end
  end

  topic 'topic2' do
    consumer Class.new
  end

  subscription_group do
    topic 'topic3' do
      consumer Class.new
    end
  end
end

assert_equal 1, Karafka::App.routes.size
assert_equal 1, Karafka::App.consumer_groups.size
assert_equal 3, Karafka::App.subscription_groups.size
assert_equal 3, Karafka::App.consumer_groups.first.topics.size
assert_equal 'topic1', Karafka::App.consumer_groups.first.topics.first.name
assert_equal 'topic2', Karafka::App.consumer_groups.first.topics[1].name
assert_equal 'topic3', Karafka::App.consumer_groups.first.topics[2].name

groups = []

groups << Karafka::App.subscription_groups.first.topics.first.subscription_group
groups << Karafka::App.subscription_groups[1].topics.first.subscription_group
groups << Karafka::App.subscription_groups[2].topics.first.subscription_group

# All anonymous groups need to be unique
assert_equal groups, groups.uniq
