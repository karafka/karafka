# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we define a pattern that gets assigned a matcher topic and this matcher topic is not part of
# the topics we want to include (by assigned name), we should not include it.

setup_karafka

Karafka::App
  .config
  .internal
  .routing
  .activity_manager
  .include(:topics, 'x')

draw_routes(create_topics: false) do
  pattern(/.*/) do
    consumer Class.new
  end
end

guarded = []

begin
  start_karafka_and_wait_until do
    true
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
