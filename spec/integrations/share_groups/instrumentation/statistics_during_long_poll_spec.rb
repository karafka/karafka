# frozen_string_literal: true

# Share group (KIP-932) statistics keep being published while the listener waits in a long poll
# without any records: like for consumer groups, the poll runs in tick-long slices and the events
# queue is serviced in between.

setup_karafka do |config|
  config.kafka[:"statistics.interval.ms"] = 1_000
  config.internal.tick_interval = 1_000
  config.max_wait_time = 30_000
  config.shutdown_timeout = 35_000
end

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:consumed] << true
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

share_sg = Karafka::App.subscription_groups.values.flatten.find { |sg| sg.group.share_group? }

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  DT[:stats] << Time.now.to_f if event[:subscription_group_id] == share_sg.id
end

start_karafka_and_wait_until do
  sleep(15)
  true
end

# Nothing to consume, so all of this happened within a single 30 seconds long poll. Statistics
# must not have been held back until the poll ended.
gaps = DT[:stats].each_cons(2).map { |first, second| second - first }

assert DT[:consumed].empty?
assert DT[:stats].size >= 10
assert gaps.max < 3
