# frozen_string_literal: true

# A topic `max_wait_time` below 10 should fail routing validation with a message that states the
# minimum, and 10 should pass. This also covers a value inherited from the root setting.

setup_karafka

error = nil

begin
  draw_routes(create_topics: false) do
    topic "max_wait_time_below_minimum" do
      consumer Class.new(Karafka::BaseConsumer)
      max_wait_time 5
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  error = e
end

assert error
assert error.message.include?("needs to be an integer bigger or equal to 10"), error.message

clear_app_draws

Karafka::App.config.max_wait_time = 5
error = nil

begin
  draw_routes(create_topics: false) do
    topic "max_wait_time_inherited_below_minimum" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  error = e
end

assert error
assert error.message.include?("needs to be an integer bigger or equal to 10"), error.message

clear_app_draws

draw_routes(create_topics: false) do
  topic "max_wait_time_at_minimum" do
    consumer Class.new(Karafka::BaseConsumer)
    max_wait_time 10
  end
end

assert_equal 10, Karafka::App.routes.first.topics.first.max_wait_time
