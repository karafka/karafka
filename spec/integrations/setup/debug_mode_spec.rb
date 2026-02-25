# frozen_string_literal: true

# Karafka should switch all components int a debug mode when we use explicit debug!

setup_karafka

draw_routes(create_topics: false) do
  topic "test" do
    active(false)
  end

  topic "test2" do
    consumer Class.new
  end

  subscription_group :test do
    topic "test3" do
      consumer Class.new
    end
  end

  consumer_group :test2 do
    topic "test4" do
      consumer Class.new
    end
  end
end

Karafka::App.debug!

assert_equal Karafka::App.logger.level, 0
assert_equal Karafka::App.producer.config.logger.level, 0
assert_equal Karafka::App.config.kafka[:debug], "all"
assert_equal Karafka::App.producer.config.kafka[:debug], "all"

Karafka::App.consumer_groups.each do |consumer_group|
  consumer_group.topics.each do |topic|
    assert_equal topic.kafka[:debug], "all"
  end
end

Karafka::App.debug!("test")

assert_equal Karafka::App.logger.level, 0
assert_equal Karafka::App.producer.config.logger.level, 0
assert_equal Karafka::App.config.kafka[:debug], "test"
assert_equal Karafka::App.producer.config.kafka[:debug], "test"

Karafka::App.consumer_groups.each do |consumer_group|
  consumer_group.topics.each do |topic|
    assert_equal topic.kafka[:debug], "test"
  end
end
