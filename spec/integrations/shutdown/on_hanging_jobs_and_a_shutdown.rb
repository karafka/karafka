# frozen_string_literal: true

# When Karafka is being shutdown and the consumer is hanging, it should force a shutdown

setup_karafka { |config| config.shutdown_timeout = 1_000 }

produce(DataCollector.topic, '1')

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[0] << true
    # This will "fake" a hanging job
    sleep(100)
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  if DataCollector.data[0].empty?
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
