# frozen_string_literal: true

# Share group (KIP-932) should keep publishing statistics after it was quieted (TSTP): the quiet
# share listener no longer polls for records but keeps servicing the events queue.

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
  next unless DT.key?(:quiet_at)

  DT[:quiet_stats] << Time.now.to_f
end

produce(DT.topic, "1")

Thread.new do
  sleep(0.1) until DT[:accepted].size.positive?

  Process.kill("TSTP", Process.pid)
end

start_karafka_and_wait_until do
  DT[:quiet_stats].size >= 10
end

assert DT[:quiet_stats].size >= 10
assert(DT[:quiet_stats].all? { |at| at > DT[:quiet_at] })
