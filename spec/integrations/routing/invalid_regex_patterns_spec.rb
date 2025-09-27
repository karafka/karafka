# frozen_string_literal: true

# Karafka should handle invalid topic names and patterns

setup_karafka

# Test with malformed topic names
malformed_failed = false

begin
  draw_routes(create_topics: false) do
    subscription_group do
      # Topic names with invalid characters
      topic "topic\x00name" do # Null byte
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  malformed_failed = true
end

# Test extremely long topic names
Karafka::App.routes.clear
long_name_failed = false

begin
  # Kafka topic names have a limit (249 characters)
  very_long_topic_name = 'a' * 300

  draw_routes(create_topics: false) do
    subscription_group do
      topic very_long_topic_name do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  long_name_failed = true
end

# Test topic names with invalid Kafka characters
Karafka::App.routes.clear
invalid_chars_failed = false

begin
  draw_routes(create_topics: false) do
    subscription_group do
      # Topic names with characters not allowed in Kafka
      topic 'topic with spaces' do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  invalid_chars_failed = true
end

# Test empty topic name
Karafka::App.routes.clear
empty_name_failed = false

begin
  draw_routes(create_topics: false) do
    subscription_group do
      topic '' do # Empty topic name
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  empty_name_failed = true
end

# We expect at least some of these edge cases to fail
assert(
  malformed_failed || long_name_failed || invalid_chars_failed || empty_name_failed,
  'At least one invalid topic name should have failed validation'
)
