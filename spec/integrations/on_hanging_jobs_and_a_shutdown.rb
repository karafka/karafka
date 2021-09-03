# frozen_string_literal: true

# When Karafka is being shutdown and the consumer is hanging, it should force a shutdown

setup_karafka { |config| config.shutdown_timeout = 1_000 }

class Consumer < Karafka::BaseConsumer
  def consume
    # This will "fake" a hanging job
    sleep
  end
end

produce(DataCollector.topic, '1')

Karafka::App.consumer_groups.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until do
  sleep(5)
  true
end

# No assertions here, as we are interested in the exit code 2 - that will indicate a force close
