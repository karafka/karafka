# frozen_string_literal: true

# When we exclude topics via a wildcard pattern, only the topics whose names match the pattern
# should become inactive. All the other routed topics stay active.

setup_karafka

draw_routes(create_topics: false) do
  topic "orders-created" do
    consumer Class.new
  end

  topic "orders-updated" do
    consumer Class.new
  end

  topic "payments-done" do
    consumer Class.new
  end
end

Karafka::App.config.internal.routing.activity_manager.exclude(:topics, "orders-*")

active = Karafka::App
  .subscription_groups
  .values
  .flatten
  .flat_map { |sg| sg.topics.map(&:name) }
  .uniq
  .sort

assert_equal %w[payments-done], active
