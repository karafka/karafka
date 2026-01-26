# frozen_string_literal: true

# Errors happening in wrap should be handled gracefully and by no means should they leak out
# If there is a chance of error (like pool timeout), it should be handled in the consumer flow
# so the consumer can back off if needed

setup_karafka(allow_errors: true) do |config|
  config.pause.with_exponential_backoff = true
  config.pause.max_timeout = 5_000
end

NoPoolObjectAvailableError = Class.new(StandardError)

DT[:attempt] = 0

# Fake pool that always raises an error because nothing available
class Pool
  class << self
    def with
      raise NoPoolObjectAvailableError
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:attempt] = attempt

    # Re-raise the error from wrapping so backoff flow can kick in
    raise @no_pool_object_error if @no_pool_object_error

    # Here some regular logic that would kick in ...
  end

  def wrap(action)
    # No need for any special actions for non-consume
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

draw_routes(Consumer)

produce(DT.topic, "")

start_karafka_and_wait_until do
  DT[:attempt] >= 5
end
