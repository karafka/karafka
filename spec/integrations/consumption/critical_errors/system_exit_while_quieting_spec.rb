# frozen_string_literal: true

# A process-critical error (SystemExit via `exit`) raised by in-flight work after the process
# was requested to quiet (TSTP) must still escalate to a full stop. Quiet parks the process but
# keeps it alive, so without the escalation it would stay parked with the failed batch.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 1
end

%w[app.quieting app.quiet app.stopping].each do |event_name|
  Karafka::App.monitor.subscribe(event_name) do
    DT[:states] << event_name
  end
end

Karafka::App.monitor.subscribe("app.stopping") do
  DT[:stopping_thread] = Thread.current.name
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:in] = true

    sleep(0.1) until Karafka::App.quieting?

    exit(1)
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

Thread.new do
  sleep(0.1) until DT.key?(:in)
  Process.kill("TSTP", Process.pid)
end

start_karafka_and_wait_until(reset_status: true) do
  DT[:states].include?("app.stopping")
end

# Quiet may be reached before the critical shutdown starts
assert_equal %w[app.quieting app.stopping], DT[:states].uniq - %w[app.quiet]
assert_equal "karafka.critical_shutdown", DT[:stopping_thread]
assert_equal 0, fetch_next_offset
