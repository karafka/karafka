# frozen_string_literal: true

# Karafka flushes the offsets once in a while. When auto offset committing is disabled, we anyhow
# should commit the offset in rebalance

setup_karafka do |config|
  config.kafka[:'enable.auto.commit'] = false
end

create_topic(partitions: 2)

Thread.new do
  loop do
    begin
      produce(DT.topic, '0', partition: 0)
      produce(DT.topic, '1', partition: 1)
    rescue WaterDrop::Errors::ProducerClosedError
      break
    end

    sleep(1)
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      next if DT[:picked].size.positive?

      DT[message.partition] << message.offset
    end
  end
end

draw_routes(Consumer)

consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(1) until DT.data.size >= 2

  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:picked] << [message.partition, message.offset]

    break
  end

  consumer.close
end

start_karafka_and_wait_until do
  other.join
end

# Should not start from beginning as the offset should be stored on rebalance
assert DT[:picked].first.last > 0
