# frozen_string_literal: true

# Karafka should reject invalid topic and consumer group names at draw time

setup_karafka

consumer_class = Class.new(Karafka::BaseConsumer)

invalid_topic_names = [
  # Null byte
  "topic\x00name",
  # Kafka topic names have a limit (249 characters)
  "a" * 300,
  # Characters not allowed in Kafka
  "topic with spaces",
  "",
  "ok\nbad name!",
  ".",
  ".."
]

accepted = []

invalid_topic_names.each do |topic_name|
  clear_app_draws

  draw_routes(create_topics: false) do
    subscription_group do
      topic topic_name do
        consumer consumer_class
      end
    end
  end

  accepted << topic_name
rescue Karafka::Errors::InvalidConfigurationError
  nil
end

clear_app_draws

begin
  draw_routes(create_topics: false) do
    consumer_group "ok\nbad cg!" do
      topic "valid_topic" do
        consumer consumer_class
      end
    end
  end

  accepted << "ok\nbad cg!"
rescue Karafka::Errors::InvalidConfigurationError
  nil
end

assert_equal [], accepted

clear_app_draws

# The longest name Kafka accepts stays valid
draw_routes(create_topics: false) do
  topic "a" * 249 do
    consumer consumer_class
  end
end
