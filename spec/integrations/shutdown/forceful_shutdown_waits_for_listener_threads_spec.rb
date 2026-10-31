# frozen_string_literal: true

# On a forceful shutdown, a terminated listener thread may still be inside a call on its client.
# The supervisor must not shut that listener down (and so call its client from another thread)
# until the listener thread has ended. Here the call ends within half of `forceful_shutdown_wait`,
# so both listeners are shut down after their threads end.
#
# Two subscription groups share one worker. The first consumes a message, then the second's
# consumer hangs. On stop, the first group's shutdown job waits behind the hanging job, so its
# listener keeps pinging its client. Each events poll of a listener defers thread termination for
# 1.5 seconds, like a native call that `Thread#terminate` cannot interrupt.
#
# This spec is registered in `bin/integrations` as expecting exit code 2 (forceful shutdown).
# A listener shut down while its thread was alive, or not shut down at all, exits with code 10 instead.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 1
  config.shutdown_timeout = 2_000
  config.max_wait_time = 500
end

Karafka::Connection::ConsumerGroups::Client.prepend(
  Module.new do
    def events_poll(timeout = 0, safe: false)
      Thread.handle_interrupt(Object => :never) do
        super
        sleep(1.5) if DT.key?(:stopping) && Thread.current.name.to_s.include?("karafka.listener")
      end
    end
  end
)

Karafka::Connection::ConsumerGroups::Listener.prepend(
  Module.new do
    def shutdown
      DT[:shutdown_alive] << alive? if DT.key?(:stopping_error)

      super
    end
  end
)

Kernel.singleton_class.prepend(
  Module.new do
    def exit!(code = false)
      if DT[:shutdown_alive] != [false, false]
        Karafka.logger.error("Listener shutdowns (thread alive?): #{DT[:shutdown_alive]}")
        code = 10
      end

      super
    end
  end
)

class Normal < Karafka::BaseConsumer
  def consume
    DT[:normal] << true
  end
end

class Hanging < Karafka::BaseConsumer
  def consume
    DT[:hanging] << true
    # Hangs past `shutdown_timeout` to force the forceful shutdown path
    sleep(30)
  end
end

# Separate consumer groups, so the second one joining does not revoke the first one's partition.
# A revocation job waiting behind the hanging job would keep the first listener from pinging.
draw_routes do
  consumer_group DT.groups[0] do
    subscription_group :a do
      topic DT.topics[0] do
        consumer Normal
      end
    end
  end

  consumer_group DT.groups[1] do
    subscription_group :b do
      topic DT.topics[1] do
        consumer Hanging
      end
    end
  end
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:stopping_error] = true if event[:type] == "app.stopping.error"
end

produce(DT.topics[0], "1")

start_karafka_and_wait_until do
  if DT.key?(:normal) && !DT.key?(:produced)
    DT[:produced] = true
    produce(DT.topics[1], "1")
  end

  next false unless DT.key?(:hanging)

  DT[:stopping] = true
end

# The forceful shutdown exits the process with code 2 from the supervising thread
sleep
