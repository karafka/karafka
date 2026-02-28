# frozen_string_literal: true

# Building subscription groups multiple times should not change their static group membership ids
# as long as topics structure is unchanged.

UUID = "TEST"

setup_karafka do |config|
  config.kafka[:"group.instance.id"] = UUID
end

draw_routes(create_topics: false) do
  subscription_group do
    topic "topic1" do
      consumer Class.new
    end
  end

  topic "topic2" do
    consumer Class.new
  end

  consumer_group :test do
    topic "topic2" do
      consumer Class.new
    end
  end
end

g00 = Karafka::App.subscription_groups.values[0][0].kafka[:"group.instance.id"]
g01 = Karafka::App.subscription_groups.values[0][1].kafka[:"group.instance.id"]
g10 = Karafka::App.subscription_groups.values[1][0].kafka[:"group.instance.id"]

assert [g00, g01, g10].uniq.size == 3
assert_equal "#{UUID}_0", g00
assert_equal "#{UUID}_1", g01
assert_equal "#{UUID}_2", g10
