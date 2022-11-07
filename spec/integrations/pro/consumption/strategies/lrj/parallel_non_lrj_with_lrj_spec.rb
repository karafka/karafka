# frozen_string_literal: true

# When using LRJ within a consumer group with other non-LRJ, the LRJ should be running while other
# jobs are consumed and they should not wait (as long as enough workers)

setup_karafka do |config|
  config.max_messages = 1
  config.concurrency = 5
  config.license.token = pro_license_token
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class LrjConsumer < Karafka::BaseConsumer
  def consume
    producer.produce_sync(topic: DT.topics[1], payload: '1')
    sleep(15)
    DT[:done_time] << Time.now
  end
end

class RegularConsumer < Karafka::BaseConsumer
  def consume
    DT[:regular_time] << Time.now
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer LrjConsumer
    long_running_job true
  end

  topic DT.topics[1] do
    consumer RegularConsumer
  end
end

produce(DT.topics[0], '1')

start_karafka_and_wait_until do
  DT[:done_time].size >= 1
end

assert DT[:regular_time][0] < DT[:done_time][0]
