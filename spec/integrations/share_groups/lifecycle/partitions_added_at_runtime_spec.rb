# frozen_string_literal: true

# Share group (KIP-932) picks up partitions added to a topic while it is running: records produced
# to the new partitions are consumed without a restart.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << [message.raw_payload, message.partition]
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce(DT.topic, "initial")

Thread.new do
  sleep(0.1) until DT[:consumed].any?

  Karafka::Admin.create_partitions(DT.topic, 3)

  # A fresh producer, so it knows about the new partitions right away
  producer = WaterDrop::Producer.new do |config|
    config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  end

  [1, 2].each do |partition|
    producer.produce_sync(topic: DT.topic, payload: "new-#{partition}", partition: partition)
  end

  producer.close
end

start_karafka_and_wait_until do
  DT[:consumed].size >= 3
end

assert_equal [["initial", 0], ["new-1", 1], ["new-2", 2]], DT[:consumed].sort
