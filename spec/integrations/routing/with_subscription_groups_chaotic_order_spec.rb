# frozen_string_literal: true

# Karafka should support chaotic order group definitions and should correctly assign the
# subscription groups

setup_karafka

draw_routes(create_topics: false) do
  topic 'topic0' do
    consumer Class.new
  end

  subscription_group 'group1' do
    topic 'topic1' do
      consumer Class.new
    end
  end

  consumer_group 'test' do
    topic 'topic1' do
      consumer Class.new
    end
  end

  topic 'topic2' do
    consumer Class.new
  end
end

subscription_groups = Karafka::App.subscription_groups

assert_equal 3, subscription_groups.values.first.count
assert_equal 1, subscription_groups.values.last.count
