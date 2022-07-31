# frozen_string_literal: true

# When Karafka is configured with short 'max.poll.interval.ms', shorter than a shutdown job, it
# should not matter. Shutdown jobs should not be terminated unless they exceed `shutdown_timeout`

setup_karafka do |config|
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.max_wait_time = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector[:received] << true
  end

  def shutdown
    # Simulate doing something longer than the poll interval
    # In case this would block polling, the other consumer will take over the job and raise an
    # exception
    sleep(15)
    DataCollector[:done] << true
  end
end

draw_routes(Consumer)

Thread.new do
  loop do
    produce(DataCollector.topic, '1')
    sleep(0.5)
  rescue WaterDrop::Errors::ProducerClosedError
    break
  end
end

# We need a second producer so we are sure that there was no revocation due to a timeout
consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(5)

  consumer.subscribe(DataCollector.topic)

  consumer.poll(1_000)

  sleep(0.1) while DataCollector[:done].empty?

  consumer.close
end

start_karafka_and_wait_until do
  !DataCollector[:received].empty?
end

other.join
