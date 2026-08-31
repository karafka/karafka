# frozen_string_literal: true

# When we mix a literal name and a wildcard pattern in a single inclusion, both the exact match
# and every wildcard match should stay active. Literal and wildcard entries coexist in the same
# include/exclude list.

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

  topic "audit-log" do
    consumer Class.new
  end
end

activity_manager = Karafka::App.config.internal.routing.activity_manager
# Literal exact match
activity_manager.include(:topics, "payments-done")
# Wildcard match
activity_manager.include(:topics, "orders-*")

active = Karafka::App
  .subscription_groups
  .values
  .flatten
  .flat_map { |sg| sg.topics.map(&:name) }
  .uniq
  .sort

assert_equal %w[orders-created orders-updated payments-done], active
