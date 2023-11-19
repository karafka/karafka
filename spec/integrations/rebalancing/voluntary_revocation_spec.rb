# frozen_string_literal: true

# When we are not kicked out forcefully but a legit rebalance occurs, we should not be marked
# as revoked when running tasks prior to reassignments.

setup_karafka do |config|
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    i = 0

    while i < 100
      DT[:status] << revoked?
      i += 1
      sleep(0.1)
    end

    DT[:done] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

produce(DT.topic, '1')

consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(0.1) until DT.key?(:status)

  consumer.subscribe(DT.topic)
  consumer.poll(1_000)
end

start_karafka_and_wait_until do
  DT.key?(:done)
end

other.join
consumer.close

assert_equal [false], DT[:status].uniq
