# frozen_string_literal: true

# Karafka should allow to use kafka scope eof without eofed enabled.

setup_karafka do |config|
  config.kafka[:'enable.partition.eof'] = true
end

failed = false

begin
  draw_routes(create_topics: false) do
    topic :topic1 do
      consumer Class.new
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert !failed
