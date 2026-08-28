# frozen_string_literal: true

# When we include subscription groups via a wildcard pattern, only the subscription groups whose
# names match the pattern should stay active.

setup_karafka

draw_routes(create_topics: false) do
  subscription_group "sg-a-1" do
    topic "t1" do
      consumer Class.new
    end
  end

  subscription_group "sg-a-2" do
    topic "t2" do
      consumer Class.new
    end
  end

  subscription_group "sg-b-1" do
    topic "t3" do
      consumer Class.new
    end
  end
end

Karafka::App.config.internal.routing.activity_manager.include(:subscription_groups, "sg-a-*")

active = Karafka::App.subscription_groups.values.flatten.map(&:name).sort

assert_equal %w[sg-a-1 sg-a-2], active
