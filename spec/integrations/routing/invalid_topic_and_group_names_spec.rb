# frozen_string_literal: true

# Topic and consumer group names Kafka rejects (a second line, `.`, `..`, over 249 characters)
# should fail routing validation at draw time.

setup_karafka

consumer_class = Class.new(Karafka::BaseConsumer)
accepted = []

["ok\nbad name!", ".", "..", "a" * 250].each do |topic_name|
  clear_app_draws

  draw_routes(create_topics: false) do
    topic topic_name do
      consumer consumer_class
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
