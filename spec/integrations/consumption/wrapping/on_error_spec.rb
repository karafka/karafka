# frozen_string_literal: true

# Errors in the processing should not affect wrapping itself

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:done] << true

    raise
  end

  def wrap(_action)
    DT[:before] = true
    yield
    DT[:after] = true
  end
end

draw_routes(Consumer)

produce(DT.topic, "")

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert DT.key?(:before)
assert DT.key?(:after)
