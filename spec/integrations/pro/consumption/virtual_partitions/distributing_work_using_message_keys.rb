# frozen_string_literal: true

# Karafka should support possibility of using message keys to distribute work
# We have two partitions but virtual partitioner should allow us to distribute this work across
# four threads concurrently.

# Note that you can get different combinations of messages for different batches fetched.
# The fact that the first time messages with key `a` were together with `c`, does not mean, that
# it will always be the same. The distribution combination is unique for the batch. One thing you
# can be sure, is that if you have messages with key `c`, they will always go to one of the
# virtual consumers. Virtual consumer instance is **not** warrantied.

TOPIC = 'integrations_20_02'

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
  config.max_messages = 5
  config.initial_offset = 'latest'
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector[0] << [message.key, message.offset]
    end

    DataCollector[:objects_ids] << object_id
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic TOPIC do
      consumer Consumer
      virtual_partitioner ->(message) { message.key }
    end
  end
end

start_karafka_and_wait_until do
  produce(TOPIC, '1', key: %w[a b c d].sample)
  produce(TOPIC, '1', key: %w[a b c d].sample)

  DataCollector[0].size >= 200
end

assert_equal 4, DataCollector[:objects_ids].uniq.size

# Messages must be order
DataCollector[0].group_by(&:first).each_value do |messages|
  previous = nil

  messages.map(&:last).each do |offset|
    unless previous
      previous = offset
      next
    end

    assert previous < offset
  end
end
