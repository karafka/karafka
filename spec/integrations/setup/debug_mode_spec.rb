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

assert_equal 0, Karafka::App.logger.level
assert_equal 0, Karafka::App.producer.config.logger.level
assert_equal "all", Karafka::App.config.kafka[:debug]
assert_equal "all", Karafka::App.producer.config.kafka[:debug]

Karafka::App.consumer_groups.each do |consumer_group|
  consumer_group.topics.each do |topic|
    assert_equal "all", topic.kafka[:debug]
  end
end

Karafka::App.debug!("test")

assert_equal 0, Karafka::App.logger.level
assert_equal 0, Karafka::App.producer.config.logger.level
assert_equal "test", Karafka::App.config.kafka[:debug]
assert_equal "test", Karafka::App.producer.config.kafka[:debug]

Karafka::App.consumer_groups.each do |consumer_group|
  consumer_group.topics.each do |topic|
    assert_equal "test", topic.kafka[:debug]
  end
end
