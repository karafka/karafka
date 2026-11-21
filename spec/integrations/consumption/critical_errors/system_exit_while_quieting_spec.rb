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

# The stop is initiated by the framework, the wait block only observes
start_karafka_and_wait_until(reset_status: true) do
  DT[:states].include?("app.stopping")
end

assert_equal %w[app.quieting app.stopping], DT[:states].first(2)
assert_equal 0, fetch_next_offset
