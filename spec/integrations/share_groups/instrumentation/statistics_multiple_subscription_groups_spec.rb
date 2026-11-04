# frozen_string_literal: true

# Share group (KIP-932) statistics from many share subscription groups should not collide: each
# share client publishes its own statistics, attributed to its own subscription group.

setup_karafka

draw_routes(create_topics: false) do
  share_group DT.groups[0] do
    topic DT.topics[0] do
      consumer Class.new(Karafka::ShareConsumer)
    end
  end

  share_group DT.groups[1] do
    topic DT.topics[1] do
      consumer Class.new(Karafka::ShareConsumer)
    end
  end
end

setup_share_group(DT.topics[0], DT.groups[0])
setup_share_group(DT.topics[1], DT.groups[1])

share_sgs = Karafka::App.subscription_groups.values.flatten.select { |sg| sg.group.share_group? }

statistics_events = {}

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  statistics_events[event[:subscription_group_id]] ||= []
  statistics_events[event[:subscription_group_id]] << event
end

start_karafka_and_wait_until do
  statistics_events.size >= 2 &&
    statistics_events.values.all? { |stats| stats.size >= 2 }
end

assert_equal 2, share_sgs.size
assert_equal share_sgs.map(&:id).sort, statistics_events.keys.sort

# Within a single subscription group, all events come from the same client and the group
share_sgs.each do |sg|
  stats = statistics_events.fetch(sg.id)
  assert_equal 1, stats.map { |event| event[:statistics]["name"] }.uniq.size
  assert_equal [sg.group.id], stats.map { |event| event[:consumer_group_id] }.uniq
end

# Each client reports only its own statistics
names = statistics_events.values.map { |stats| stats.first[:statistics]["name"] }
assert_equal 2, names.uniq.size
