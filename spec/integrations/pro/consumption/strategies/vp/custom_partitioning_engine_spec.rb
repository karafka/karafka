# frozen_string_literal: true

SPECIAL_TOPIC = DT.topics[0]

setup_karafka

class CustomPartitioner < Karafka::Pro::Processing::Partitioner
  def call(topic_name, messages, &block)
    if topic_name == SPECIAL_TOPIC
      balanced_strategy(messages, &block)
    else
      super
    end
  end

  private

  def balanced_strategy(messages)
    messages.each_slice(20).with_index do |slice, index|
      yield(index, slice)
    end
  end
end

setup_karafka do |config|
  config.concurrency = 2
  config.max_messages = 500
  config.max_wait_time = 5_000
  config.initial_offset = 'earliest'
  config.internal.processing.partitioner_class = CustomPartitioner
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[topic.name] << messages.count
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    # Irrelevant because we use custom partitioner
    virtual_partitions
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

10.times do
  produce_many(DT.topics[0], DT.uuids(1_000))
end

produce_many(DT.topics[1], DT.uuids(1_000))

start_karafka_and_wait_until do
  DT[DT.topics[0]].sum >= 5_000 &&
    DT[DT.topics[1]].sum >= 100
end

p DT
