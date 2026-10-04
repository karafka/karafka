# frozen_string_literal: true

# Share group (KIP-932) statistics keep flowing while a batch is being processed. The listener
# does not poll for records until the batch is done, but it still services the events queue, so
# `statistics.emitted` keeps being published during long processing.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:started_at] << Time.now.to_f
    sleep(7)
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

Karafka.monitor.subscribe("statistics.emitted") do |event|
  DT[:stats] << Time.now.to_f if event[:subscription_group_id] == share_sg.id
end

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT.key?(:finished_at)
end

started_at = DT[:started_at].first
finished_at = DT[:finished_at].first

assert DT[:stats].any? { |at| at > started_at && at < finished_at }
