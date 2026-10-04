# frozen_string_literal: true

# Share group (KIP-932) consumers support `#wrap` around their actions (`:consume`, `:idle`,
# `:shutdown`), so state like a checked out producer is available during consumption.

setup_karafka

PRODUCER = rand

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:producer] = producer

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end

  def wrap(action)
    DT[:actions] << action

    return yield unless action == :consume

    default_producer = producer
    self.producer = PRODUCER

    yield

    self.producer = default_producer
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
assert_equal PRODUCER, DT[:producer]
assert_equal :consume, DT[:actions].first
assert_equal :shutdown, DT[:actions].last
