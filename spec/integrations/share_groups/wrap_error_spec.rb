# frozen_string_literal: true

# Share group (KIP-932) errors raised inside `#wrap` (like a pool checkout timeout) do not leak
# out. When the consumer re-raises them from `#consume`, the records are released and redelivered,
# so the work is retried.

setup_karafka(allow_errors: %w[consumer.consume.error])

NoPoolObjectAvailableError = Class.new(StandardError)

# Fake pool that always raises an error because nothing available
class Pool
  class << self
    def with
      raise NoPoolObjectAvailableError
    end
  end
end

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:deliveries] << messages.first.delivery_count

    # Re-raise the error from wrapping so the records are released and redelivered
    raise @no_pool_object_error if @no_pool_object_error
  end

  def wrap(action)
    return yield unless action == :consume

    Pool.with do |_producer|
      yield
    end
  rescue NoPoolObjectAvailableError => e
    @no_pool_object_error = e

    yield
  ensure
    @no_pool_object_error = false
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:error].class
end

setup_share_group

produce(DT.topic, "")

start_karafka_and_wait_until do
  DT[:deliveries].size >= 3
end

assert_equal [1, 2, 3], DT[:deliveries].first(3)
assert_equal [NoPoolObjectAvailableError], DT[:errors].uniq
