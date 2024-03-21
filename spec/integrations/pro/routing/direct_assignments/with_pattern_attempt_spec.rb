# frozen_string_literal: true

# We should not allow for usage of patterns with direct assignments

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    pattern(/#{DT.topic}/) do
      consumer Class.new(Karafka::BaseConsumer)
      assign(0)
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
