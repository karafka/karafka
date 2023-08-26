# frozen_string_literal: true

# We should not be able to define same pattern multiple times in the same consumer group

setup_karafka

guarded = []

begin
  draw_routes(create_topics: false) do
    pattern(/non-existing-ever-na/) do
      consumer Class.new
    end

    pattern(/non-existing-ever-na/) do
      consumer Class.new
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
