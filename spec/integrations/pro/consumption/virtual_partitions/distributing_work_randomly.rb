# frozen_string_literal: true

# Karafka should support possibility of distributing work randomly when using virtual partitions
# Note that even when using random distribution, messages from different partitions will never
# mix within a batch.

TOPIC = 'integrations_21_02'

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 5
  config.max_messages = 20
  config.initial_offset = 'latest'
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector[object_id] << message.offset
    end
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic TOPIC do
      consumer Consumer
      virtual_partitioner ->(_) { rand(Karafka::App.config.concurrency) }
    end
  end
end

start_karafka_and_wait_until do
  produce(TOPIC, '1', key: %w[a b c d].sample)
  produce(TOPIC, '1', key: %w[a b c d].sample)

  DataCollector.data.values.map(&:count).sum >= 1_000
end

# Two partitions, 3-5 jobs per each
assert DataCollector.data.size >= 8
