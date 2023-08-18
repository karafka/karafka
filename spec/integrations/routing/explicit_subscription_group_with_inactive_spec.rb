# frozen_string_literal: true

# Karafka should allow for nice subscription groups management style with nesting DSL

setup_karafka

draw_routes do
  subscription_group 'group1' do
    topic 'topic1' do
      consumer Class.new
      active false
    end
  end

  topic 'topic2' do
    consumer Class.new
    active false
  end

  subscription_group 'group2' do
    topic 'topic3' do
      consumer Class.new
      active false
    end

    topic 'topic4' do
      consumer Class.new
    end
  end
end

subscription_groups = Karafka::App.subscription_groups.values.flatten

assert_equal 1, Karafka::App.routes.size
assert_equal 1, Karafka::App.consumer_groups.size
assert_equal 1, subscription_groups.size
