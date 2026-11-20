# frozen_string_literal: true

# A topic `max_wait_time` below 10 should fail routing validation with a message stating the minimum.

setup_karafka

message = nil

begin
  draw_routes(create_topics: false) do
    topic "max_wait_time_below_minimum" do
      consumer Class.new(Karafka::BaseConsumer)
      max_wait_time 5
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  message = e.message
end

assert message.to_s.include?("needs to be an integer bigger or equal to 10"), message
