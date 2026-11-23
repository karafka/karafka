# frozen_string_literal: true

# When librdkafka cannot build a message and the poll window is used up (no retry), Karafka should
# report it via `error.occurred` with its details, raise it, reset the client and fetch the
# message again, so it is not skipped.

setup_karafka(allow_errors: %w[connection.client.poll.error connection.listener.fetch_loop.error])

module BrokenHeaders
  def rd_kafka_message_headers(native_message, headers_ptrptr)
    if native_message[:offset] == 2 && !DT.key?(:broken)
      DT[:broken] = true

      # RD_KAFKA_RESP_ERR__BAD_MSG
      return -199
    end

    super
  end
end

Rdkafka::Bindings.singleton_class.prepend(BrokenHeaders)

# Simulates the error landing at the end of the poll window
module NoRetry
  def retryable?
    if DT.key?(:broken) && !DT.key?(:retry_blocked)
      DT[:retry_blocked] = true

      return false
    end

    super
  end
end

Karafka::TimeTrackers::Poll.prepend(NoRetry)

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes(Consumer)
produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:offsets].include?(4)
end

poll_error, fetch_loop_error = DT[:errors]

assert_equal 2, DT[:errors].size
assert_equal "connection.client.poll.error", poll_error[:type]
assert_equal :bad_msg, poll_error[:error].code
assert_equal DT.topic, poll_error[:error].details[:topic]
assert_equal 0, poll_error[:error].details[:partition]
assert_equal 2, poll_error[:error].details[:offset]
assert_equal "connection.listener.fetch_loop.error", fetch_loop_error[:type]
assert_equal poll_error[:error], fetch_loop_error[:error]
# Fetched again after the reset: nothing skipped
assert_equal (0..4).to_a, DT[:offsets].uniq.sort
assert DT[:offsets].index(2) < DT[:offsets].index(4)
