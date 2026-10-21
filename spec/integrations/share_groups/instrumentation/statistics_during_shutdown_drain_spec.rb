# frozen_string_literal: true

# Share group (KIP-932) should keep publishing statistics while the shutdown drains a consume job
# that is still running after the stop was requested. Events are serviced on each tick.

setup_karafka do |config|
  config.internal.tick_interval = 1_000
end

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:started_at] << Time.now.to_f
    sleep(5)
    DT[:finished_at] << Time.now.to_f

    messages.each { |message| mark_as_accepted(message) }
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

Karafka::App.monitor.subscribe("app.stopping") do
  DT[:stopping_at] = Time.now.to_f
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  DT[:stats] << Time.now.to_f if event[:subscription_group_id] == share_sg.id
end

produce(DT.topic, "1")

# Request the stop as soon as the consumption started
start_karafka_and_wait_until do
  DT.key?(:started_at)
end

stopping_at = DT[:stopping_at]
finished_at = DT[:finished_at].first

in_drain = DT[:stats].select { |at| at > stopping_at && at < finished_at }

assert stopping_at < finished_at
# Statistics kept flowing across the whole drain, not only once it ended
assert in_drain.size >= 5
assert in_drain.max - in_drain.min >= 2
