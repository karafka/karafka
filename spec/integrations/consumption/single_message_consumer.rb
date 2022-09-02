# frozen_string_literal: true

# With a custom per message consumer abstraction layer, we should be able to use "1.4 style"
# of using per-message consumers while retaining decent performance and warranties

setup_karafka

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
    DT[message.metadata.partition] << message.raw_payload
  end
end

draw_routes(Consumer)

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

assert_equal elements, DT[0]
assert_equal 1, DT.data.size
