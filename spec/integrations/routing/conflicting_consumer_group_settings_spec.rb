# frozen_string_literal: true

# Karafka should detect conflicting configurations that cause namespace collisions

setup_karafka

# Test namespace collision within same consumer group (like existing test)
failed = false

begin
  draw_routes(create_topics: false) do
    topic "namespace_collision" do
      consumer Class.new
    end

    topic "namespace.collision" do # Creates metrics namespace collision
      consumer Class.new
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed, "Should have raised InvalidConfigurationError for namespace collision"

# Test empty consumer class assignment
Karafka::App.routes.clear

class ConsumerA < Karafka::BaseConsumer; end
class ConsumerB < Karafka::BaseConsumer; end

begin
  draw_routes(create_topics: false) do
    topic :no_consumer_topic do
      # No consumer defined - this should fail validation
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  # Expected failure for missing consumer
end

# Test multiple topics with same consumer (should be allowed)
Karafka::App.routes.clear
multiple_topics_passed = true

begin
  draw_routes(create_topics: false) do
    topic :topic_one do
      consumer ConsumerA
    end

    topic :topic_two do
      # Same consumer, different topic - should be ok
      consumer ConsumerA
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  multiple_topics_passed = false
end

# Core configuration conflicts should be detected
assert failed, "Namespace collisions should be detected"
assert multiple_topics_passed, "Same consumer on different topics should be allowed"
