# frozen_string_literal: true

# Karafka when consuming messages, should report per topic partition consumer lag
# Since librdkafka fetches data in batches onto the queue, this can cause the lagged partition to
# run first without processing anything else despite good concurrency settings
# This can be solved either via subscription group distribution or by tuning the per partition data
# that goes into the buffer
# ref https://github.com/edenhill/librdkafka/wiki/FAQ#how-are-partitions-fetched

setup_karafka do |config|
  config.max_messages = 2
  config.concurrency = 2
  # We set those values high so only the first topic is consumed as long as it lags
  config.kafka[:'fetch.message.max.bytes'] = 262_144 * 100
  config.kafka[:'queued.max.messages.kbytes'] = 2_097_151
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed! message
      sleep(0.05)
    end
  end
end

produce_many(DT.topics[0], Array.new(100) { '1' })
produce_many(DT.topics[1], Array.new(50) { '1' })

Karafka::App.monitor.subscribe('statistics.emitted') do |event|
  event.payload[:statistics]['topics'].each do |topic_name, topic_values|
    topic_values['partitions'].each do |partition_name, partition_values|
      next if partition_name == '-1'

      lag = partition_values['consumer_lag']

      next if lag == -1

      DT[topic_name] << lag
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    subscription_group_id '1'
  end

  topic DT.topics[1] do
    consumer Consumer
    subscription_group_id '2'
  end
end

start_karafka_and_wait_until do
  DT.data.size >= 2 && DT.data.values.all? { |values| values.include?(0) }
end

bigger = DT.data[DT.topics[0]]
smaller = DT.data[DT.topics[1]]

assert (98..100).include?(bigger[0])
assert (48..50).include?(smaller[0])

assert_equal 0, bigger.last
assert_equal 0, smaller.last
