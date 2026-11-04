# frozen_string_literal: true

# Share group (KIP-932) topics should be switched into debug mode with an explicit `debug!` the
# same way as consumer group ones. When enabled before routing, share clients get built with it.

setup_karafka

Karafka::App.debug!

draw_routes(create_topics: false) do
  share_group DT.group do
    topic "test" do
      active(false)
    end

    topic "test2" do
      consumer Class.new(Karafka::ShareConsumer)
    end

    subscription_group :test do
      topic "test3" do
        consumer Class.new(Karafka::ShareConsumer)
      end
    end
  end

  share_group "#{DT.group}-2" do
    topic "test4" do
      consumer Class.new(Karafka::ShareConsumer)
    end
  end
end

share_groups = Karafka::App.routes.share_groups

assert_equal 2, share_groups.size

share_groups.each do |group|
  group.subscription_groups.each do |subscription_group|
    assert_equal "all", subscription_group.kafka[:debug]
  end
end

%w[all test].each do |contexts|
  Karafka::App.debug!(contexts)

  assert_equal 0, Karafka::App.logger.level
  assert_equal 0, Karafka::App.producer.config.logger.level
  assert_equal contexts, Karafka::App.config.kafka[:debug]
  assert_equal contexts, Karafka::App.producer.config.kafka[:debug]

  share_groups.each do |group|
    group.topics.each do |topic|
      assert_equal contexts, topic.kafka[:debug]
    end
  end
end
