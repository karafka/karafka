# frozen_string_literal: true

# When a fiber job hangs in a scheduler-blind busy loop (the worst case for the fibers backend,
# as it freezes its whole carrier thread), forceful shutdown must still be able to terminate
# the carrier and force-exit the process

setup_karafka(allow_errors: true) do |config|
  config.workers.backend = :fibers
  config.workers.concurrency = 5
  config.shutdown_timeout = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true

    # Busy loop never yields to the fiber scheduler, freezing the carrier thread entirely
    loop {} # rubocop:disable Lint/EmptyBlock
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

start_karafka_and_wait_until do
  if DT[0].empty?
    false
  else
    sleep 1
    true
  end
end

# This sleep is not a problem. Since Karafka runs in a background thread and in this scenario is
# suppose to exit with 2 from a different thread, we just block it so Karafka has time to actually
# end the process as expected
sleep

# No assertions here, as we are interested in the exit code 2 - that will indicate a force close
