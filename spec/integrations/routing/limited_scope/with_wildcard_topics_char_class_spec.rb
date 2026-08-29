# frozen_string_literal: true

# The wildcard matching uses File.fnmatch?, so besides `*` it must also honor `[...]` character
# classes. `topic-[12]` should match only `topic-1` and `topic-2`.

setup_karafka

draw_routes(create_topics: false) do
  topic "topic-1" do
    consumer Class.new
  end

  topic "topic-2" do
    consumer Class.new
  end

  topic "topic-3" do
    consumer Class.new
  end
end

Karafka::App.config.internal.routing.activity_manager.include(:topics, "topic-[12]")

active = Karafka::App
  .subscription_groups
  .values
  .flatten
  .flat_map { |sg| sg.topics.map(&:name) }
  .uniq
  .sort

assert_equal %w[topic-1 topic-2], active
