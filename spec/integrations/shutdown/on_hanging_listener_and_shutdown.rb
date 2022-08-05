# frozen_string_literal: true

# When Karafka is being shutdown and the consumer thread is hanging for too long, it should force
# a shutdown despite having active connections to Kafka

setup_karafka(allow_errors: true) { |config| config.shutdown_timeout = 1_000 }

produce(DT.topic, '1')

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      max_messages 1
      consumer Consumer
    end
  end
end

occurence = 0

# This will force Karafka fetcher to hang
Karafka.monitor.subscribe('connection.listener.fetch_loop.received') do
  sleep if occurence.positive?

  occurence += 1
end

Thread.new do
  start_karafka_and_wait_until do
    if DT[0].empty?
      false
    else
      sleep 1
      true
    end
  end
end

sleep

# No assertions here, as we are interested in the exit code 2 - that will indicate a force close
