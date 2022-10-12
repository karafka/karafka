# frozen_string_literal: true

# We do not spec zstd to make sure that the exception is raised when trying to use compression that
# does not have all the required packages.

error = nil

begin
  setup_karafka do |config|
    config.kafka[:'compression.codec'] = 'zstd'
  end

  draw_routes(Class.new(Karafka::BaseConsumer))
rescue Karafka::Errors::InvalidConfigurationError => e
  error = e
end

assert error.message.include?('libzstd not available at build time')
