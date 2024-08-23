# frozen_string_literal: true

# Karafka should not allow to use eofed when kafka scope setup is not with eof

setup_karafka

# When enable.partition.eof is not defined at all
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

assert failed
