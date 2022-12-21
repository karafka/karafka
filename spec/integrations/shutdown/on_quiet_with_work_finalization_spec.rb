# frozen_string_literal: true

# When Karafka is being moved to quiet mode, it is requested to first reach quieting and then stop
# on the quiet state.

setup_karafka do |config|
  config.concurrency = 1
end

Karafka::App.monitor.subscribe('app.quieting') do
  DT[:states] << Karafka::App.config.internal.status.to_s
end

Karafka::App.monitor.subscribe('app.quiet') do
  DT[:states] << Karafka::App.config.internal.status.to_s
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:in] << true
    sleep(2)
  end
end

draw_routes(Consumer)

produce(DT.topic, '1')

Thread.new do
  sleep(0.1) while DT[:in].empty?
  Process.kill('TSTP', ::Process.pid)
end

start_karafka_and_wait_until do
  DT[:states].count >= 2
end

assert_equal DT[:states], %w[quieting quiet]
