# frozen_string_literal: true

# Karafka should recover from critical (non-StandardError) errors raised in user consumption
# code. Such errors are contained at the consumer level (so the regular retry flow engages and
# the failed batch is not skipped) and reported on the error bus. Because the failing batch is
# retried, the error may be reported more than once.
#
# @note This test is a bit special as due to how Karafka operates, when unexpected issue happens
#   in particular moments, it can bubble up and exit 2

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 1
end

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

SuperException = Class.new(Exception)

Karafka.monitor.subscribe(Listener.new)

class Consumer < Karafka::BaseConsumer
  def consume
    raise SuperException
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(5))

raised = false

begin
  start_karafka_and_wait_until do
    # This means, that listener received critical error
    DT.key?(:errors)
  end
rescue SuperException
  raised = true
end

assert_equal false, raised
# The failing batch is retried, so by the time we stop, the error may have been reported more
# than once
assert DT[:errors].size >= 1
assert_equal "error.occurred", DT[:errors].first.id
assert_equal "consumer.consume.error", DT[:errors].first.payload[:type]
