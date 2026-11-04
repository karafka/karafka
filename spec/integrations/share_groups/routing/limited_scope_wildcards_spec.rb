# frozen_string_literal: true

# Share group (KIP-932) include/exclude filters should support wildcard patterns the same way as
# consumer group filters do. Subscription group and topic filters (wildcards included) should
# apply to share groups as well, and share group filters must not affect consumer groups.

setup_karafka

Consumer = Class.new(Karafka::BaseConsumer)
ShareConsumer = Class.new(Karafka::ShareConsumer)

AM = Karafka::App.config.internal.routing.activity_manager

# Active subscription groups are narrowed in place, so we redraw for every filters combination
def redraw
  AM.clear
  clear_app_draws

  draw_routes(create_topics: false) do
    consumer_group "app-a-cg" do
      topic "cg-topic" do
        consumer Consumer
      end
    end

    share_group "app-a-orders" do
      topic "orders-1" do
        consumer ShareConsumer
      end
    end

    share_group "app-a-payments" do
      subscription_group "payments-sg" do
        topic "payments-1" do
          consumer ShareConsumer
        end
      end
    end

    share_group "app-b-orders" do
      topic "orders-2" do
        consumer ShareConsumer
      end
    end
  end
end

def active_groups
  Karafka::App.subscription_groups.keys.map(&:name).sort
end

def active_topics
  Karafka::App.subscription_groups.values.flatten.flat_map { |sg| sg.topics.map(&:name) }.sort
end

redraw
AM.include(:share_groups, "app-a-*")
assert_equal %w[app-a-cg app-a-orders app-a-payments], active_groups

redraw
AM.exclude(:share_groups, "app-a-*")
assert_equal %w[app-a-cg app-b-orders], active_groups

redraw
AM.exclude(:share_groups, "*")
assert_equal %w[app-a-cg], active_groups

redraw
AM.include(:share_groups, "app-?-orders")
assert_equal %w[app-a-cg app-a-orders app-b-orders], active_groups

redraw
AM.include(:subscription_groups, "payments-*")
assert_equal %w[app-a-payments], active_groups

redraw
AM.exclude(:topics, "orders-*")
assert_equal %w[cg-topic payments-1], active_topics

redraw
AM.include(:topics, "orders-[12]")
assert_equal %w[orders-1 orders-2], active_topics
