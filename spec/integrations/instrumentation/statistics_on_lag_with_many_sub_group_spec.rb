# frozen_string_literal: true

# Karafka when consuming messages, should report per topic partition consumer lag
# By using two subscription groups, we can make sure we have separate connections and that we
# fetch data in parallel and ship it as it goes, so one topic partition data is not causing
# a wait on other things
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
      sleep(1)
    end
  end
end

produce_many(DT.topics[0], Array.new(20) { '1' })
produce_many(DT.topics[1], Array.new(10) { '1' })

Karafka::App.monitor.subscribe('statistics.emitted') do |event|
  event.payload[:statistics]['topics'].each do |topic_name, topic_values|
    topic_values['partitions'].each do |partition_name, partition_values|
      next if partition_name == '-1'

      lag = partition_values['consumer_lag']

      next if lag == -1

      DT[topic_name] << lag
      DT[:overall] << "#{topic_name}/#{lag}"
    end
  end
end

draw_routes do
  subscription_group '1' do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  subscription_group '2' do
    topic DT.topics[1] do
      consumer Consumer
    end
  end
end

bigger = DT.data[DT.topics[0]]
smaller = DT.data[DT.topics[1]]

start_karafka_and_wait_until do
  DT.data.size >= 3 && [bigger, smaller].all? { |values| values.include?(0) }
end

assert (18..20).cover?(bigger[0])
assert (8..10).cover?(smaller[0])

assert_equal 0, bigger.last
assert_equal 0, smaller.last

previous = nil
continuous = true
at_least_one_non_order = false

# We check here, that we actually consume and publish metrics from both topics and that each of
# them can put their data independently and in its own order (one does not block the other)
DT[:overall].each do |point|
  topic, lag = point.split('/')

  unless previous
    previous = topic

    next
  end

  at_least_one_non_order = true if previous != topic

  continuous = false if lag.to_i == '0'
end

assert at_least_one_non_order
