# frozen_string_literal: true

# Share group (KIP-932) errors raised in `#consume` do not break `#wrap`: the code after `yield`
# still runs and the records are released for redelivery.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:deliveries] << messages.first.delivery_count

    raise StandardError if messages.first.delivery_count == 1

    messages.each { |message| mark_as_accepted(message) }
    DT[:accepted] = true
  end

  def wrap(action)
    return yield unless action == :consume

    DT[:before] << true
    yield
    DT[:after] << true
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

produce(DT.topic, "")

start_karafka_and_wait_until do
  DT.key?(:accepted)
end

assert_equal [1, 2], DT[:deliveries].first(2)
assert_equal DT[:before].size, DT[:after].size
assert DT[:after].size >= 2
