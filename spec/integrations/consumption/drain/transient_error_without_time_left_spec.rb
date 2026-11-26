# frozen_string_literal: true

# When a transient error (e.g. a timeout) comes behind a message and the batch has no time left
# for a retry, Karafka should report it and raise it, as the next blocking poll would, reset the
# client and continue from the committed offset with no gap. With a low `max_wait_time` this is the
# case users hit.
#
# The error is injected into whichever poll call comes after the first message, so the spec does
# not depend on whether that call is a blocking poll or a drain.

MESSAGES = 100

setup_karafka(
  allow_errors: %w[connection.client.poll.error connection.listener.fetch_loop.error]
) do |config|
  config.max_wait_time = 100
end

TIMED_OUT = Rdkafka::RdkafkaError.new(Rdkafka::Bindings::RD_KAFKA_RESP_ERR__TIMED_OUT)

module InjectedTimeout
  def poll(timeout_ms)
    raise TIMED_OUT if inject?

    message = super
    DT[:polled] = true if message
    message
  end

  def poll_batch_nb(timeout_ms = 0, max_items: 100)
    return super unless inject?

    DT[:drained] = true

    [TIMED_OUT, *super]
  end

  private

  def inject?
    return false unless DT.key?(:polled)
    return false if DT.key?(:injected)

    DT[:injected] = true
  end
end

Rdkafka::Consumer.prepend(InjectedTimeout)

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event
end

Karafka.monitor.subscribe("client.reset") do
  DT[:resets] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes(Consumer)
produce_many(DT.topic, DT.uuids(MESSAGES))

start_karafka_and_wait_until do
  DT[:offsets].include?(MESSAGES - 1)
end

poll_error, fetch_loop_error = DT[:errors]

assert DT.key?(:injected)
assert_equal 2, DT[:errors].size
assert_equal "connection.client.poll.error", poll_error[:type]
assert_equal TIMED_OUT, poll_error[:error]
assert_equal "connection.listener.fetch_loop.error", fetch_loop_error[:type]
assert_equal TIMED_OUT, fetch_loop_error[:error]
assert_equal 1, DT[:resets].size
assert_equal (0...MESSAGES).to_a, DT[:offsets].uniq.sort
