# frozen_string_literal: true

# When we include consumer groups via a wildcard pattern, only the consumer groups whose names
# match the pattern should stay active.

setup_karafka

draw_routes(create_topics: false) do
  consumer_group "app-a-orders" do
    topic "t1" do
      consumer Class.new
    end
  end

  consumer_group "app-a-payments" do
    topic "t2" do
      consumer Class.new
    end
  end

  consumer_group "app-b-orders" do
    topic "t3" do
      consumer Class.new
    end
  end
end

Karafka::App.config.internal.routing.activity_manager.include(:consumer_groups, "app-a-*")

active = Karafka::App.subscription_groups.keys.map(&:name).sort

assert_equal %w[app-a-orders app-a-payments], active
