# frozen_string_literal: true

# When strict declarative topics validation is enabled, share-group topics need an active
# declaration from `declaratives.draw`, the same as consumer-group topics need one.

setup_karafka do |config|
  config.strict_declarative_topics = true
end

# A share-group topic declared in `declaratives.draw` before the routing passes the check
draw_topics(create_topics: false) do
  topic "share-topic" do
    partitions 1
  end
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

# A share-group topic without a declaration fails the check
failed = false

begin
  draw_routes(create_topics: false) do
    share_group "sg2" do
      topic "share-topic2" do
        active(false)
        consumer Class.new(Karafka::ShareConsumer)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  failed = e.message.include?("share-topic2")
end

assert failed

clear_app_draws

# A share-group topic with an inactive declaration fails the check
draw_topics(create_topics: false) do
  topic "share-topic3" do
    active false
  end
end

failed = false

begin
  draw_routes(create_topics: false) do
    share_group "sg3" do
      topic "share-topic3" do
        active(false)
        consumer Class.new(Karafka::ShareConsumer)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed

clear_app_draws

# The strict check still enforces declaratives on consumer-group topics when a declared share
# group is present in the same routing tree
draw_topics(create_topics: false) do
  topic "share-topic4" do
    partitions 1
  end
end

failed = false

begin
  draw_routes(create_topics: false) do
    consumer_group "cg4" do
      topic "not-declared" do
        active(false)
        consumer Class.new(Karafka::BaseConsumer)
        config(active: false)
      end
    end

    share_group "sg4" do
      topic "share-topic4" do
        active(false)
        consumer Class.new(Karafka::ShareConsumer)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  failed = e.message.include?("not-declared") && !e.message.include?("share-topic4")
end

assert failed
