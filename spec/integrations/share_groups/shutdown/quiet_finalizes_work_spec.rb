# frozen_string_literal: true

# Share group (KIP-932): when moved to quiet mode during processing, Karafka should first reach
# quieting, finish the in-flight batch and only then reach the quiet state.

setup_karafka do |config|
  config.concurrency = 1
end

Karafka::App.monitor.subscribe("app.quieting") do
  DT[:states] << Karafka::App.config.internal.status.to_s
end

Karafka::App.monitor.subscribe("app.quiet") do
  DT[:states] << Karafka::App.config.internal.status.to_s
  DT[:done_when_quiet] = DT[:done].dup
end

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:in] << true
    sleep(2)
    messages.each { |message| mark_as_accepted(message) }
    DT[:done] << true
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

produce(DT.topic, "1")

Thread.new do
  sleep(0.1) while DT[:in].empty?
  Process.kill("TSTP", Process.pid)
end

start_karafka_and_wait_until do
  DT[:states].size >= 2
end

assert_equal %w[quieting quiet], DT[:states]
assert_equal [true], DT[:done_when_quiet]
