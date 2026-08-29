# frozen_string_literal: true

# When we include topics via a wildcard pattern, only the topics whose names match the pattern
# should stay active. Non-matching topics become inactive even though they were routed.

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

Karafka::App.config.internal.routing.activity_manager.include(:topics, "orders-*")

active = Karafka::App
  .subscription_groups
  .values
  .flatten
  .flat_map { |sg| sg.topics.map(&:name) }
  .uniq
  .sort

assert_equal %w[orders-created orders-updated], active
