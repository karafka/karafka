# frozen_string_literal: true

# Share group (KIP-932) with statistics.interval.ms set to 0 should not emit any statistics, so
# the statistics decorator is never called.

setup_karafka do |config|
  config.kafka[:"statistics.interval.ms"] = 0
end

ORIGINAL_DIFF = Karafka::Core::Monitoring::StatisticsDecorator.instance_method(:diff)

Karafka::Core::Monitoring::StatisticsDecorator.define_method(:diff) do |*args|
  DT[:diff_called] << true
  ORIGINAL_DIFF.bind_call(self, *args)
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  DT[:stats] << event
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].size >= 10
end

assert_equal elements.sort, DT[:accepted].sort
assert_equal 0, DT[:diff_called].size
assert_equal 0, DT[:stats].size
