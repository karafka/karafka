# frozen_string_literal: true

# Share group (KIP-932) statistics stop once the process is quiet (TSTP): unlike a consumer group, a
# quiet share group closes its client, so it does not acquire records it will not process.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
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

Karafka::App.monitor.subscribe("connection.listener.quiet") do
  DT[:quiet_at] = Time.now.to_f
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  next unless event[:subscription_group_id] == share_sg.id

  DT[DT.key?(:quiet_at) ? :quiet_stats : :stats] << Time.now.to_f
end

produce(DT.topic, "1")

Thread.new do
  sleep(0.1) until DT[:accepted].size.positive?

  Process.kill("TSTP", Process.pid)
end

start_karafka_and_wait_until do
  # Statistics are emitted every 100ms, so 2 seconds is plenty for them to show up if they did
  DT.key?(:quiet_at) && Time.now.to_f - DT[:quiet_at] > 2
end

assert DT[:stats].size.positive?
assert DT[:quiet_stats].empty?
