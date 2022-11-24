# frozen_string_literal: true

# Building subscription groups multiple times should not change their static group membership ids
# as long as topics structure is unchanged.

UUID = 'TEST'

setup_karafka do |config|
  config.kafka[:'group.instance.id'] = UUID
end

draw_routes do
  subscription_group do
    topic 'topic1' do
      consumer Class.new
    end
  end

  topic 'topic2' do
    consumer Class.new
  end

  consumer_group :test do
    topic 'topic2' do
      consumer Class.new
    end
  end
end

g00 = Karafka::App.subscription_groups.values[0][0].kafka[:'group.instance.id']
g01 = Karafka::App.subscription_groups.values[0][1].kafka[:'group.instance.id']
g10 = Karafka::App.subscription_groups.values[1][0].kafka[:'group.instance.id']

assert [g00, g01, g10].uniq.count == 3
assert_equal g00, "#{UUID}_0"
assert_equal g01, "#{UUID}_1"
assert_equal g10, "#{UUID}_2"
