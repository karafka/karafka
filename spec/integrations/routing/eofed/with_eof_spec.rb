# frozen_string_literal: true

# Karafka should allow to use eofed when kafka scope setup is with eof

setup_karafka do |config|
  config.kafka[:'enable.partition.eof'] = true
end

failed = false

begin
  draw_routes(create_topics: false) do
    topic :topic1 do
      consumer Class.new
      eofed true
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert !failed
