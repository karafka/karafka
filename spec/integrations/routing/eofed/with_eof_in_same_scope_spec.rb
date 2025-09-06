# frozen_string_literal: true

# Karafka should allow to use eofed when kafka scope setup is with eof in same sub-scope

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    topic :topic1 do
      consumer Class.new
      eofed true
      kafka(
        'bootstrap.servers': kafka_bootstrap_servers,
        'enable.partition.eof': true
      )
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert !failed
