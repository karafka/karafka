# frozen_string_literal: true

# When we define a pattern that gets assigned a matcher topic and this matcher topic is part of
# the topics we do not want to include (by assigned name) it should not use it

setup_karafka

draw_routes(create_topics: false) do
  pattern(/non-existing-ever-na/) do
    consumer Class.new
  end
end

Karafka::App
  .config
  .internal
  .routing
  .activity_manager
  .include(:topics, 'something-else')

guarded = []

begin
  start_karafka_and_wait_until do
    true
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
