# frozen_string_literal: true

# When we have a valid name but provide regexp that is not a regexp, we should fail

setup_karafka

guarded = []

begin
  draw_routes(create_topics: false) do
    pattern('super-name1', 'not-a-regexp') do
      consumer Class.new
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
