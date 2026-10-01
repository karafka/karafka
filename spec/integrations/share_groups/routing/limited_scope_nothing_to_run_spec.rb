# frozen_string_literal: true

# When the share groups (KIP-932) are the only routed groups and all of them end up inactive
# (inactive topics, excluded share groups or non-matching wildcard inclusions), Karafka should
# refuse to start instead of starting with nothing to subscribe to.

setup_karafka

ShareConsumer = Class.new(Karafka::ShareConsumer)

AM = Karafka::App.config.internal.routing.activity_manager

def expect_refusal
  spotted = false

  begin
    start_karafka_and_wait_until { false }
  rescue Karafka::Errors::InvalidConfigurationError
    spotted = true
  end

  assert spotted

  AM.clear
  clear_app_draws
end

# Only inactive share topics
draw_routes(create_topics: false) do
  share_group "sg1" do
    topic "t1" do
      active(false)
      consumer ShareConsumer
    end
  end
end

expect_refusal

# All share groups excluded
draw_routes(create_topics: false) do
  share_group "sg1" do
    topic "t1" do
      consumer ShareConsumer
    end
  end

  share_group "sg2" do
    topic "t2" do
      consumer ShareConsumer
    end
  end
end

AM.exclude(:share_groups, "sg1")
AM.exclude(:share_groups, "sg2")

expect_refusal

# Wildcard inclusion matching no share group
draw_routes(create_topics: false) do
  share_group "sg1" do
    topic "t1" do
      consumer ShareConsumer
    end
  end
end

AM.include(:share_groups, "non-matching-*")

expect_refusal

# Unknown share group inclusion
draw_routes(create_topics: false) do
  share_group "sg1" do
    topic "t1" do
      consumer ShareConsumer
    end
  end
end

AM.include(:share_groups, "non-existing")

expect_refusal
