# frozen_string_literal: true

# When Karafka is forcefully stopped, the supervisor closes the listeners' clients from a separate
# thread (`listeners.each(&:shutdown)`). A listener that kept running after that would reopen its
# client: the client builds a new consumer lazily on the next call (e.g. the `ping` in
# `wait_pinging`), and a fetch loop error would reset and retry it. Neither may happen - the
# supervisor terminates active listener threads before it closes their clients.
#
# To make a race likely, every events poll on the listener blocks natively for up to 500ms, so the
# listener spends most of its time inside a native client call while the consume job hangs.
#
# This spec is registered in `bin/integrations` as expecting exit code 2 (forceful shutdown). A
# client reopened (or reset, or a fetch loop still running) after the forceful stop exits with
# code 10 instead.

setup_karafka(allow_errors: true) do |config|
  config.shutdown_timeout = 2_000
  config.max_wait_time = 500
  config.internal.tick_interval = 1_000
end

Karafka::Connection::ConsumerGroups::Client.prepend(
  Module.new do
    # Keeps the listener inside a native, blocking client call most of the time
    def events_poll(_timeout = 0, safe: false)
      super(500, safe: safe)
    end

    private

    # A consumer built after the forceful stop means the closed client got reopened
    def build_consumer
      DT[:after_stop] << "client reopened" if DT.key?(:stopping_error)

      super
    end
  end
)

# Last moment before the process exits. Give a misbehaving listener time to act on the closed
# client, then turn any recorded misbehavior into a failing exit code
Kernel.singleton_class.prepend(
  Module.new do
    def exit!(code = false)
      sleep(3)

      unless DT[:after_stop].empty?
        Karafka.logger.error("Listener used a client closed by forceful shutdown: #{DT[:after_stop]}")
        code = 10
      end

      super
    end
  end
)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << true
    # Hangs past `shutdown_timeout` to force the forceful shutdown path
    sleep(30)
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:stopping_error] = true if event[:type] == "app.stopping.error"

  next unless DT.key?(:stopping_error)
  next unless event[:type] == "connection.listener.fetch_loop.error"

  DT[:after_stop] << "fetch loop error: #{event[:error].class}"
end

Karafka.monitor.subscribe("client.reset") do
  DT[:after_stop] << "client reset" if DT.key?(:stopping_error)
end

Karafka.monitor.subscribe("connection.listener.fetch_loop") do
  DT[:after_stop] << "fetch loop iteration" if DT.key?(:stopping_error)
end

start_karafka_and_wait_until do
  DT.key?(:consumed)
end

# The forceful shutdown exits the process with code 2 from the supervising thread
sleep
