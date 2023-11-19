# frozen_string_literal: true

# When max messages format is not as expected, we should fail

Karafka::App.setup do |config|
  config.max_messages = '100'
end

failed = false

begin
  draw_routes do
    topic DT.topic do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
