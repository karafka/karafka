# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When naming a pattern and then not including it, it should not be used

setup_karafka

draw_routes(create_topics: false) do
  pattern('super-name', /non-existing-ever-na/) do
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
