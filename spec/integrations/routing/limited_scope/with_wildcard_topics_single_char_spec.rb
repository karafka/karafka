# frozen_string_literal: true

# The wildcard matching uses File.fnmatch?, so besides `*` it must also honor the single
# character `?` wildcard. `topic-?` should match single-character suffixes (`topic-1`, `topic-x`)
# but not the two-character `topic-42`.

setup_karafka

draw_routes(create_topics: false) do
  topic "topic-1" do
    consumer Class.new
  end

  topic "topic-x" do
    consumer Class.new
  end

  topic "topic-42" do
    consumer Class.new
  end
end

Karafka::App.config.internal.routing.activity_manager.include(:topics, "topic-?")

active = Karafka::App
  .subscription_groups
  .values
  .flatten
  .flat_map { |sg| sg.topics.map(&:name) }
  .uniq
  .sort

assert_equal %w[topic-1 topic-x], active
