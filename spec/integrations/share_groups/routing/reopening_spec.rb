# frozen_string_literal: true

# Karafka should allow reopening share groups (KIP-932) across multiple draw calls, the same way
# as consumer groups. Topics should accumulate in the one share group, subscription groups should
# be rebuilt to include the new topics and their positions should stay stable across redraws.

setup_karafka

Consumer = Class.new(Karafka::ShareConsumer)

draw_routes(create_topics: false) do
  share_group :sg do
    topic "t1" do
      consumer Consumer
    end
  end
end

first_positions = Karafka::App.routes.share_groups.first.subscription_groups.map(&:position)

draw_routes(create_topics: false) do
  share_group "sg" do
    topic "t2" do
      consumer Consumer
    end

    subscription_group "custom" do
      topic "t3" do
        consumer Consumer
      end
    end
  end

  share_group "other" do
    topic "t1" do
      consumer Consumer
    end
  end
end

# Empty draws are a no-op
draw_routes(create_topics: false) {}

share_groups = Karafka::App.routes.share_groups

assert_equal %w[sg other], share_groups.map(&:name)

sg = share_groups.first

assert_equal %w[t1 t2 t3], sg.topics.map(&:name)

sgs = sg.subscription_groups

assert_equal %w[t1 t2], sgs.first.topics.map(&:name)
assert_equal %w[t3], sgs.last.topics.map(&:name)
assert_equal "custom", sgs.last.name
assert_equal first_positions.first, sgs.first.position

all_ids = Karafka::App.subscription_groups.values.flatten.map(&:id)

assert_equal all_ids.uniq, all_ids
