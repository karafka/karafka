# frozen_string_literal: true

# When strict declarative topics validation is enabled, drawing routes that include a share group
# should not crash. Share-group topics do not support declarative management (nor DLQ), so they
# are exempt from the strict declarative check, while consumer-group topics remain validated.

setup_karafka do |config|
  config.strict_declarative_topics = true
end

# Mixed routing with a share group must draw cleanly (consumer topic has declaratives by default)
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
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

assert_equal 2, Karafka::App.routes.size

clear_app_draws

# The strict check must still enforce declaratives on consumer-group topics when a share group
# is present in the same routing tree
failed = false

begin
  draw_routes(create_topics: false) do
    consumer_group "cg2" do
      topic "not-declared" do
        active(false)
        consumer Class.new(Karafka::BaseConsumer)
        config(active: false)
      end
    end

    share_group "sg2" do
      topic "share-topic2" do
        active(false)
        consumer Class.new(Karafka::BaseConsumer)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
