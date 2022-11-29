# frozen_string_literal: true

# When building subscription groups and then using a limited subset of consumer groups simulating
# the --consumer_groups flag should not impact the numbers in the group

UUID = 'TEST'

setup_karafka do |config|
  config.kafka[:'group.instance.id'] = UUID
end

draw_routes do
  consumer_group :test1 do
    subscription_group do
      topic 'topic1' do
        consumer Class.new
      end
    end
  end

  consumer_group :test2 do
    topic 'topic2' do
      consumer Class.new
    end
  end

  topic 'topic2' do
    consumer Class.new
  end
end

# We skip the middle one and check the positions later
Karafka::App.config.internal.routing.active.consumer_groups = %w[test1 app]

# Two consumer groups
assert_equal 2, Karafka::App.subscription_groups.keys.size

# Correct once
assert_equal 'test1', Karafka::App.subscription_groups.keys[0].name
assert_equal 'app', Karafka::App.subscription_groups.keys[1].name

g00 = Karafka::App.subscription_groups.values[0][0].kafka[:'group.instance.id']
g10 = Karafka::App.subscription_groups.values[1][0].kafka[:'group.instance.id']

assert_equal "#{UUID}_0", g00
assert_equal "#{UUID}_2", g10
