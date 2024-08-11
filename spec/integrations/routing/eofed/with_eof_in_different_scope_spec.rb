# frozen_string_literal: true

# Karafka should not allow to use eofed when kafka scope setup is with eof in different sub-scope

setup_karafka do |config|
  config.kafka[:'enable.partition.eof'] = true
end

failed = false

begin
  draw_routes(create_topics: false) do
    topic :topic1 do
      consumer Class.new
      eofed true
      kafka('bootstrap.servers': '127.0.0.1:9092')
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
