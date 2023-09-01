# frozen_string_literal: true

# When having a named pattern that would be excluded by the CLI, it should not be used

setup_karafka

draw_routes(create_topics: false) do
  pattern('named-pattern', /non-existing-ever-na/) do
    consumer Class.new
  end
end

Karafka::App
  .config
  .internal
  .routing
  .activity_manager
  .exclude(:topics, 'named-pattern')

guarded = []

begin
  start_karafka_and_wait_until do
    true
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
