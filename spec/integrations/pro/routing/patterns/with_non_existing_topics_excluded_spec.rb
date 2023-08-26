# frozen_string_literal: true

# When we define a pattern that gets assigned a matcher topic and this matcher topic is not part of
# the 

setup_karafka

draw_routes(create_topics: false) do
  pattern(/#{DT.topic}/) do
    consumer Class.new
  end
end

Karafka::App
  .config
  .internal
  .routing
  .activity_manager
  .exclude(:topics, [DT.topic])

start_karafka_and_wait_until do
  true
end
