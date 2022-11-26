# frozen_string_literal: true

# When using the Long Running Job feature, in case partition is lost during the processing, after
# partition is reclaimed, process should pick it up and continue. It should not hang in the pause
# state forever.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 1
end

create_topic(partitions: 2)

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(15)

    DT[messages.first.partition] << messages.first.offset

    raise
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
    end
  end
end

other = Thread.new do
  sleep(10)

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:jumped] << [message.partition, message.offset]
    sleep 15
    consumer.store_offset(message)
    break
  end

  consumer.commit(nil, false)

  consumer.close
end

Thread.new do
  loop do
    produce(DT.topic, '1', partition: [0, 1].sample)
    sleep(0.1)
  rescue WaterDrop::Errors::ProducerClosedError
    break
  end
end

start_karafka_and_wait_until do
  DT[0].size >= 3 &&
    DT[1].size >= 3
end

other.join

lost = DT[:jumped][0][0]
not_lost = lost == 0 ? 1 : 0

assert_equal [0], DT[not_lost].uniq
assert DT[not_lost].size >= 3
assert_equal [0, 1], DT[lost].uniq
