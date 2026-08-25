# frozen_string_literal: true

# When we exclude topics via a wildcard pattern that matches none of the routed topics, the
# exclusion is a benign no-op: every topic stays active and there is something to subscribe to
# (unlike a non-matching wildcard inclusion, which leaves nothing active). Wildcard exclusions
# skip the "must match an existing route" contract check, so this must not raise.

setup_karafka

draw_routes(create_topics: false) do
  topic "orders-created" do
    consumer Class.new
  end

  topic "payments-done" do
    consumer Class.new
  end
end

Karafka::App.config.internal.routing.activity_manager.exclude(:topics, "non-existing-*")

active = Karafka::App
  .subscription_groups
  .values
  .flatten
  .flat_map { |sg| sg.topics.map(&:name) }
  .uniq
  .sort

# Nothing matched the exclusion, so all topics remain active
assert_equal %w[orders-created payments-done], active

# And it boots cleanly (there is something to subscribe to)
spotted = false

begin
  start_karafka_and_wait_until do
    true
  end
rescue Karafka::Errors::InvalidConfigurationError
  spotted = true
end

assert !spotted
