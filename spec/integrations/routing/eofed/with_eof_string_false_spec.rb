# frozen_string_literal: true

# Karafka should not allow to use eofed when kafka scope setup has eof set to the "false" string

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = "false"
end

failed = false

begin
  draw_routes(create_topics: false) do
    topic :topic1 do
      consumer Class.new(Karafka::BaseConsumer)
      eofed true
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
