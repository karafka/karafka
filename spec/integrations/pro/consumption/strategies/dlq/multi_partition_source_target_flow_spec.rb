# frozen_string_literal: true

# When handling failing messages from a many partitions and there are many errors, DLQ will provide
# strong ordering warranties inside DLQ.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.license.token = pro_license_token
end

create_topic(name: DT.topics[0], partitions: 10)
create_topic(name: DT.topics[1], partitions: 10)

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      DT[:partitions] << message.partition
    end

    raise StandardError
  end
end

class DlqConsumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      DT["broken-#{message.partition}"] << message.headers['original-partition']
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

10.times do |i|
  elements = DT.uuids(100)
  produce_many(DT.topic, elements, partition: i)
end

start_karafka_and_wait_until do
  DT[:partitions].uniq.count >= 10 &&
    DT.data.keys.uniq.count >= 5
end

samples = {}

# Data from given original partition should only be present in one target partition
DT.data.each do |k, v|
  next if k == :partitions

  v.each do |original_partition|
    samples[original_partition] ||= []
    samples[original_partition] << k
  end
end

# Each original partition data should always go to one and the same target partition
samples.each do |_, sources|
  assert_equal 1, sources.uniq.count, sources
end
