# frozen_string_literal: true

# Karafka should support possibility of distributing work randomly when using virtual partitions
# Note that even when using random distribution, messages from different partitions will never
# mix within a batch.

setup_karafka do |config|
  config.concurrency = 5
  config.max_messages = 20
  config.initial_offset = 'latest'
end

create_topic(partitions: 2)

class VirtualPartitioner
  def initialize
    @current = 0
    @max = Karafka::App.config.concurrency - 1
    @set = (0..@max).to_a
  end

  def call(_)
    @current += 1
    @current = 0 if @current > @max
    @set[@current]
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[object_id] << message.offset
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(
        partitioner: VirtualPartitioner.new
      )
    end
  end
end

start_karafka_and_wait_until do
  produce(DT.topic, '1', key: %w[a b c d].sample)
  produce(DT.topic, '1', key: %w[a b c d].sample)

  DT.data.values.map(&:count).sum >= 1_000
end

# Two partitions, 5 jobs per each
assert_equal 10, DT.data.size
