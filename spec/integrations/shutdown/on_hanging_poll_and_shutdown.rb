# frozen_string_literal: true

# When Karafka is being shutdown and the consumer thread is hanging for too long, it should force
# a shutdown despite having active connections to Kafka

setup_karafka { |config| config.shutdown_timeout = 1_000 }

produce(DataCollector.topic, '1')

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[0] << true
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      # This will force Karafka to be in a "permanent" poll
      max_wait_time 100_000_000
      max_messages 1
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until do
  if DataCollector.data[0].empty?
    false
  else
    sleep 1
    true
  end
end

sleep

# No assertions here, as we are interested in the exit code 2 - that will indicate a force close
