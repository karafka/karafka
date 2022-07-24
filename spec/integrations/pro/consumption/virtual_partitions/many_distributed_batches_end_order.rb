# frozen_string_literal: true

# When consuming data with virtual partitions from many batches, the order of messages in between
# the single partition batches should be preserved.

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

Karafka.monitor.subscribe('connection.listener.fetch_loop.received') do |event|
  next if event.payload[:messages_buffer].empty?

  DataCollector[:batches] << Concurrent::Array.new
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    DataCollector[:batches].last.push(*messages)
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      virtual_partitioner ->(msg) { msg.raw_payload }
    end
  end
end

start_karafka_and_wait_until do
  if DataCollector[:batches].map(&:size).sum < 1000
    elements = Array.new(100) { SecureRandom.uuid }
    elements.each { |data| produce(DataCollector.topic, data) }
    sleep(1)
    false
  else
    true
  end
end

# Sort messages from each of the batches
DataCollector[:batches].map! do |batch|
  batch.sort_by!(&:offset)
end

previous = nil

# They need to be in order one batch after another
DataCollector[:batches].flatten.map(&:offset).each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset

  previous = offset
end
