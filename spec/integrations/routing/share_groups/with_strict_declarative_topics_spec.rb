# frozen_string_literal: true

# When strict declarative topics validation is enabled, share-group topics are declarative by
# default like consumer-group topics, and a share-group topic that opts out of its declaration
# fails the strict check.

setup_karafka do |config|
  config.strict_declarative_topics = true
end

draw_routes(create_topics: false) do
  consumer_group "cg" do
    topic "declared" do
      active(false)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "sg" do
    topic "share-topic" do
      active(false)
      consumer Class.new(Karafka::ShareConsumer)
    end
  end
end

assert_equal 2, Karafka::App.routes.size

clear_app_draws

failed = false

begin
  draw_routes(create_topics: false) do
    share_group "sg2" do
      topic "share-topic2" do
        active(false)
        consumer Class.new(Karafka::ShareConsumer)
        config(active: false)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
