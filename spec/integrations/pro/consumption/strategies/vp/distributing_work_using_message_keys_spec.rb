# frozen_string_literal: true

# Karafka should support possibility of using message keys to distribute work
# We have two partitions but virtual partitioner should allow us to distribute this work across
# four threads concurrently.

# Note that you can get different combinations of messages for different batches fetched.
# The fact that the first time messages with key `a` were together with `c`, does not mean, that
# it will always be the same. The distribution combination is unique for the batch. One thing you
# can be sure, is that if you have messages with key `c`, they will always go to one of the
# virtual consumers. Virtual consumer instance is **not** warrantied.

setup_karafka do |config|
  config.concurrency = 10
  config.max_messages = 5
  config.initial_offset = 'latest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [message.key, message.offset]
    end

    DT[:objects_ids] << object_id
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      config(partitions: 2)
      consumer Consumer
      virtual_partitions(
        partitioner: ->(message) { message.key }
      )
    end
  end
end

start_karafka_and_wait_until do
  produce(DT.topic, '1', key: %w[a b c d].sample)
  produce(DT.topic, '1', key: %w[a b c d].sample)

  DT[0].size >= 200
end

assert_equal 4, DT[:objects_ids].uniq.size

# Messages must be order
DT[0].group_by(&:first).each_value do |messages|
  previous = nil

  messages.map(&:last).each do |offset|
    unless previous
      previous = offset
      next
    end

    assert previous < offset
  end
end
