# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we define a pattern that gets assigned a matcher topic and this matcher topic is part of
# the topics we want to include (by given name) it should be ok

setup_karafka

draw_routes(create_topics: false) do
  pattern('my_special_name', /non-existing-ever-na/) do
    consumer Class.new
  end
end

Karafka::App
  .config
  .internal
  .routing
  .activity_manager
  .include(:topics, 'my_special_name')

start_karafka_and_wait_until do
  true
end
