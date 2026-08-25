# frozen_string_literal: true

# When we include topics via a wildcard pattern that matches none of the routed topics, every
# topic becomes inactive and there is nothing to subscribe to. Wildcard inclusions skip the
# "must match an existing route" contract check, but the server must still refuse to boot with
# an InvalidConfigurationError instead of silently starting with no subscriptions.

setup_karafka

draw_routes(create_topics: false) do
  consumer_group "a" do
    subscription_group "b" do
      topic "c" do
        consumer Class.new
      end
    end
  end
end

activity_manager = Karafka::App.config.internal.routing.activity_manager

# Matches nothing (no routed topic starts with "non-existing-")
activity_manager.include(:topics, "non-existing-*")

spotted = false

begin
  # This should fail with an exception as there is nothing left to subscribe to
  start_karafka_and_wait_until do
    false
  end
rescue Karafka::Errors::InvalidConfigurationError
  spotted = true
end

assert spotted
