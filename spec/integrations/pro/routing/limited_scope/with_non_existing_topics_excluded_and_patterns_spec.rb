# frozen_string_literal: true

# When we define only names of topics we want to exclude and they do not exist, this should be ok
# as long as we use pattern matching because they may come later even if there are no other
# topics

setup_karafka

draw_routes(create_topics: false) do
  pattern(/.*/) do
    consumer Class.new
  end
end

Karafka::App
  .config
  .internal
  .routing
  .activity_manager
  .exclude(:topics, %w[x y z])

start_karafka_and_wait_until do
  true
end
