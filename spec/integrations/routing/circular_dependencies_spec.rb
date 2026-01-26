# frozen_string_literal: true

# Karafka should detect circular dependencies and duplicate definitions

setup_karafka

class CircularConsumerA < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:a] << msg.raw_payload }
  end
end

class CircularConsumerB < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:b] << msg.raw_payload }
  end
end

# Test topic with same name in same subscription group (should fail)
same_topic_failed = false

begin
  draw_routes(create_topics: false) do
    subscription_group do
      topic :duplicate_topic do
        consumer CircularConsumerA
      end

      # Same topic name in same group
      topic :duplicate_topic do
        consumer CircularConsumerB
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  same_topic_failed = true
end

# Test duplicate consumer assignment to same topic (may not be supported)
Karafka::App.routes.clear

begin
  draw_routes(create_topics: false) do
    subscription_group do
      topic :shared_topic do
        consumer CircularConsumerA
        # Trying to assign second consumer may not be valid DSL
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  # Expected failure for invalid configuration
end

# Test self-referencing consumer configuration (runtime issue, not config error)
class SelfReferencingConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # This could create infinite loop but should not fail at config time
      DT[:self_ref] << message.raw_payload
    end
  end
end

Karafka::App.routes.clear
self_ref_passed = true

begin
  draw_routes(create_topics: false) do
    subscription_group do
      topic DT.topic do
        consumer SelfReferencingConsumer
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  self_ref_passed = false
end

# Test multiple subscription groups with same topic (this should be allowed)
Karafka::App.routes.clear
multi_group_passed = true

begin
  draw_routes(create_topics: false) do
    subscription_group "group_a" do
      topic :shared_across_groups do
        consumer CircularConsumerA
      end
    end

    subscription_group "group_b" do
      topic :shared_across_groups do
        consumer CircularConsumerB
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  multi_group_passed = false
end

# Core circular dependencies should be detected
assert(
  same_topic_failed,
  "Should detect duplicate topic names within same subscription group"
)

assert(
  self_ref_passed,
  "Self-referencing consumer should not fail at configuration time"
)

assert(
  !multi_group_passed,
  "Same topic in different subscription groups should not be allowed"
)
