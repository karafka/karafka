# frozen_string_literal: true

# Karafka should be able to easily consume all the messages from earliest (default) using multiple
# threads based on the used virtual partitioner. We should use more than one thread for processing
# of all the messages

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector[object_id] << message
    end
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

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector.data.values.map(&:size).sum >= 100
end

# Since Ruby hash function is slightly nondeterministic, not all the threads may always be used
# but in general more than 5 need to be always
assert DataCollector.data.size >= 5

# On average we should have similar number of messages
sizes = DataCollector.data.values.map(&:size)
average = sizes.sum / sizes.count
# Small deviations may be expected
assert average >= 8
assert average <= 12

# All data within partitions should be in order
DataCollector.data.each do |_object_id, messages|
  previous_message = nil

  messages.each do |message|
    unless previous_message
      previous_message = message
      next
    end

    assert previous_message.offset < message.offset
  end
end
