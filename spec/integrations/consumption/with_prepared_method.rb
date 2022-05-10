# frozen_string_literal: true

# Karafka consumer can be used with `#prepared` method to run some preparations before running the
# proper code
# While it is not recommended to use it unless you are advanced user and want to elevate certain
# karafka capabilities, we still add this spec to make sure things operate as expected and that
# this method is called

setup_karafka

class Consumer < Karafka::BaseConsumer
  # We should have access here to anything that we can get when consuming, so we duplicate
  # this and we can compare that later
  def prepared
    messages.each do |message|
      DataCollector.data["prep-#{message.metadata.partition}"] << message.raw_payload
    end
  end

  def consume
    messages.each do |message|
      DataCollector.data[message.metadata.partition] << message.raw_payload
    end
  end
end

Karafka::App.monitor.instrument('consumer.prepared') do
  DataCollector.data[:prepared] = true
end

draw_routes(Consumer)

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 100
end

assert_equal DataCollector.data['prep-0'], DataCollector.data[0]
assert_equal 3, DataCollector.data.size
assert_equal true, DataCollector.data[:prepared]
