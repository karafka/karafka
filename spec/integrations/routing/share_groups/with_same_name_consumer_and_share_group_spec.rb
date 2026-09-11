# frozen_string_literal: true

# Kafka uses a single group-id namespace for consumer groups and share groups, so defining a
# consumer group and a share group with the same name must be rejected during routing validation
# instead of silently producing two routing groups with duplicate ids.

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    consumer_group "duplicated" do
      topic "t1" do
        active(false)
        consumer Class.new(Karafka::BaseConsumer)
      end
    end

    share_group "duplicated" do
      topic "t1" do
        active(false)
        consumer Class.new(Karafka::BaseConsumer)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed

clear_app_draws

# Distinct names remain perfectly valid
draw_routes(create_topics: false) do
  consumer_group "cg-name" do
    topic "t1" do
      active(false)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "sg-name" do
    topic "t1" do
      active(false)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

assert_equal 2, Karafka::App.routes.size

clear_app_draws

# Re-opening the same consumer group remains valid (it is one group, not a duplicate)
draw_routes(create_topics: false) do
  consumer_group "reopened" do
    topic "t1" do
      active(false)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  consumer_group "reopened" do
    topic "t2" do
      active(false)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

assert_equal 1, Karafka::App.routes.size
assert_equal 2, Karafka::App.routes.first.topics.size
