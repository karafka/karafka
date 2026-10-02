# frozen_string_literal: true

# Share group (KIP-932) topics can reconfigure their kafka scope the same way consumer group
# topics do: without `inherit` the whole scope is replaced (so missing bootstrap.servers is an
# error), with `inherit: true` the root settings are merged, and invalid librdkafka properties are
# reported via the routing contract. Topics with different kafka settings within one share group
# land in separate subscription groups that all use the share group name as group.id.

setup_karafka

Consumer = Class.new(Karafka::ShareConsumer)

failed = []

begin
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "t" do
        consumer Consumer
        kafka("max.poll.records": 5)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("routes.sg.t.kafka.bootstrap.servers"), e.message

  failed << :bootstrap
end

clear_app_draws

begin
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "t" do
        consumer Consumer
        kafka("not.existing.property": 5, inherit: true)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("routes.sg.t.kafka"), e.message
  assert e.message.include?("not.existing.property"), e.message

  failed << :invalid
end

clear_app_draws

assert_equal %i[bootstrap invalid], failed

draw_routes(create_topics: false) do
  share_group "sg" do
    topic "t1" do
      consumer Consumer
      kafka("max.poll.records": 5, inherit: true)
    end

    topic "t2" do
      consumer Consumer
    end

    topic "t3" do
      consumer Consumer
      kafka("bootstrap.servers": "127.0.0.1:9092", "max.poll.records": 7)
    end
  end
end

topics = Karafka::App.routes.share_groups.first.topics.to_a

# Inherited settings keep the root ones
assert_equal 5, topics[0].kafka.fetch(:"max.poll.records")
assert_equal 100, topics[0].kafka.fetch(:"statistics.interval.ms")
# Not reconfigured topics use the root ones
assert_equal Karafka::App.config.kafka, topics[1].kafka
# Fully replaced settings do not carry root ones
assert !topics[2].kafka.key?(:"statistics.interval.ms")

sgs = Karafka::App.routes.share_groups.first.subscription_groups

assert_equal 3, sgs.size
assert_equal 3, sgs.map(&:id).uniq.size
assert_equal %w[sg], sgs.map { |sg| sg.kafka.fetch(:"group.id") }.uniq
assert_equal [5, 100, 7], sgs.map { |sg| sg.kafka.fetch(:"max.poll.records") }
