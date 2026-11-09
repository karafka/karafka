# frozen_string_literal: true

# On a forceful shutdown, a terminated listener thread that is still inside a call on its client
# after half of `forceful_shutdown_wait` must not be shut down from another thread. It is skipped
# and reported, while the other listener is still shut down.
#
# Two subscription groups share one worker. The first consumes a message, then the second's
# consumer hangs. On stop, the first group's shutdown job waits behind the hanging job, so its
# listener keeps pinging its client. Each events poll of that listener defers thread termination
# for 10 seconds with native `usleep` calls, like a native call that `Thread#terminate` cannot
# interrupt. Not with `sleep`: JRuby delivers `Thread#terminate` into it even inside
# `Thread.handle_interrupt(Object => :never)`. Many short calls, as MRI cuts one long call short.
# Only the first group's listener defers: the second one also polls events once per
# `tick_interval` while it waits on its job, and could then be skipped too.
#
# This spec is registered in `bin/integrations` as expecting exit code 2 (forceful shutdown).
# A listener shut down while its thread was alive, or no report, exits with code 10 instead.

module LibC
  extend FFI::Library

  ffi_lib FFI::Library::LIBC

  attach_function :usleep, [:uint], :int, blocking: true
end

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
        if DT.key?(:stopping) &&
            subscription_group.name == "a" &&
            Thread.current.name.to_s.include?("karafka.listener")
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10

          LibC.usleep(10_000) while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        end
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
      if DT[:shutdown_alive] != [false] || DT[:skipped].size != 1
        Karafka.logger.error(
          "Listener shutdowns (thread alive?): #{DT[:shutdown_alive]}, skipped: #{DT[:skipped]}"
        )
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

Karafka.monitor.subscribe("connection.listener.shutdown.skipped") do |event|
  DT[:skipped] << event[:listener].id
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
