# frozen_string_literal: true

# When consuming on multiple workers, when one receives a non-critical exception, others should
# continue processing and the one should be retried

setup_karafka do |config|
  config.concurrency = 10
  config.initial_offset = 'latest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    @count ||= 0
    @count += 1

    # This will simulate, that the thread is busy in a bit random way, so more worker threads can
    # be occupied
    sleep(1)

    messages.each do |message|
      DataCollector[message.partition] << message.raw_payload
    end

    raise StandardError if @count == 1 && messages.first.partition == 5
  end

  def on_shutdown
    mark_as_consumed!(messages.last)
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    # Special topic with 10 partitions available
    topic 'integrations_0_10' do
      consumer Consumer
    end
  end
end

# Start Karafka
Thread.new { Karafka::Server.run }

# Give it some time to boot and connect before dispatching messages
sleep(5)

10.times { |i| produce('integrations_0_10', SecureRandom.uuid, partition: i) }

wait_until do
  DataCollector.data.values.flatten.size >= 11
end

# 10 partitions are expected
assert_equal 10, DataCollector.data.size
# In 11 messages are expected as insert in one will be retried due to error
assert_equal 11, DataCollector.data.values.flatten.count
# We sent 10, we expect 10
assert_equal 10, DataCollector.data.values.flatten.uniq.count
