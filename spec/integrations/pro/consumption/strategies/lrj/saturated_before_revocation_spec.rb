# frozen_string_literal: true

# When we have a LRJ job and revocation happens, non revocation aware LRJ should not cause a
# timeout because the revocation job is also non-blocking.

setup_karafka(allow_errors: %w[connection.client.poll.error]) do |config|
  config.concurrency = 2
  config.max_messages = 1
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

events = []

Karafka::App.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'connection.client.poll.error'

  events << event
end

create_topic(partitions: 2)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:any] << object_id

    sleep(1) while DT[:done].empty?

    sleep(15)
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
      manual_offset_management true
    end
  end
end

produce(DT.topic, '1', partition: 0)
produce(DT.topic, '1', partition: 1)

start_karafka_and_wait_until do
  sleep(0.1) while DT[:any].uniq.size < 2

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topics[0])
  consumer.each { break }
  consumer.close

  DT[:done] << true

  sleep(15)

  true
end

assert events.empty?, events
