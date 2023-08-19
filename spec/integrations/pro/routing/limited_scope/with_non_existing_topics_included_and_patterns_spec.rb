# frozen_string_literal: true

# When we define only names of topics we want to include and they do not exist, this should be ok
# as long as we use pattern matching because they may come later

setup_karafka

draw_routes(create_topics: false) do
  pattern /.*/ do
    consumer Class.new
  end
end

Karafka::App
  .config
  .internal
  .routing
  .activity_manager
  .include(:topics, %w[x y z])

# This should not crash in case we defined patterns, because in cases like this we cannot
# check for topics existence as they may come later
#
# It should also NOT raise an exception that there are no active topics, because the placeholder
# topic should always be active even with included topics defined.
start_karafka_and_wait_until do
  true
end
