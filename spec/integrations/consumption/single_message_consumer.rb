# frozen_string_literal: true

# With a custom per message consumer abstraction layer, we should be able to use "1.4 style"
# of using per-message consumers while retaining decent performance and warranties

setup_karafka

elements = Array.new(20) { SecureRandom.uuid }

# Abstraction layer on top of Karafka to build a "per message" consumers
class SingleMessageBaseConsumer < Karafka::BaseConsumer
  attr_reader :message

  def consume
    messages.each do |message|
      @message = message
      consume_one
    end

    # This could be moved into the loop but would slow down the processing, it's a trade-off
    # between retrying the batch and processing performance
    mark_as_consumed(messages.last)
  end
end

class Consumer < SingleMessageBaseConsumer
  def consume_one
    DataCollector.data[message.metadata.partition] << message.raw_payload
  end
end

draw_routes(Consumer)

elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 20
end

assert_equal elements, DataCollector.data[0]
assert_equal 1, DataCollector.data.size
