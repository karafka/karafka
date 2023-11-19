# frozen_string_literal: true

# When we have anonymous pattern with a non-regexp value, it should validate and fail

setup_karafka

guarded = []

begin
  draw_routes(create_topics: false) do
    pattern('not-a-regexp') do
      consumer Class.new
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
