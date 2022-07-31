# frozen_string_literal: true

# Karafka when used with VP and manual offset management should anyhow commit proper offset at
# the end. This means that unless errors / rebalance, the offset commits should not impact the flow

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed(message) if [true, false].sample
      DataCollector[object_id] << message.offset
    end
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      virtual_partitioner ->(msg) { msg.raw_payload }
      manual_offset_management true
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
DataCollector.data.each do |_object_id, offsets|
  previous_offset = nil

  offsets.each do |offset|
    unless previous_offset
      previous_offset = offset
      next
    end

    assert previous_offset < offset
  end
end
