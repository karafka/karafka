# frozen_string_literal: true

# We can pause and after revocation and re-claim we should continue processing like pause did
# not happen. We should not keep the pause after a rebalance.
#
# Messages that were consumed by another process should not be re-consumed.

setup_karafka do |config|
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    partition = messages.metadata.partition

    if !DT[:paused].include?(partition) && @second
      pause(messages.last.offset + 1, 100_000)

      DT[:paused] << partition

      return
    end

    messages.each do |message|
      DT[partition] << message.offset
    end

    @second = true
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
  end
end

Thread.new do
  loop do
    produce(DT.topic, '1', partition: [0, 1].sample)
    sleep(0.1)
  rescue WaterDrop::Errors::ProducerClosedError
    break
  end
end

consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(10)

  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:jumped] << [message.partition, message.offset]
    sleep 10
    consumer.store_offset(message)
    break
  end

  consumer.commit(nil, false)

  consumer.close
end

start_karafka_and_wait_until do
  DT[0].size >= 100 &&
    DT[1].size >= 100
end

lost_partition = DT[:jumped][0]

assert !DT[lost_partition].include?(DT[:jumped][1])

other.join
