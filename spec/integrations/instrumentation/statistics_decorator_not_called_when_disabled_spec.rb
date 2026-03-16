# frozen_string_literal: true

# When statistics.interval.ms is set to 0, librdkafka does not emit statistics callbacks.
# This means Karafka::Core::Monitoring::StatisticsDecorator#diff should never be called.

setup_karafka do |config|
  config.kafka[:"statistics.interval.ms"] = 0
end

# Track if the decorator's diff method is ever called
ORIGINAL_DIFF = Karafka::Core::Monitoring::StatisticsDecorator.instance_method(:diff)

Karafka::Core::Monitoring::StatisticsDecorator.define_method(:diff) do |*args|
  DT[:diff_called] << true
  ORIGINAL_DIFF.bind(self).call(*args)
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal elements, DT[0]
# With statistics.interval.ms set to 0, diff should never have been called
assert_equal 0, DT[:diff_called].size
