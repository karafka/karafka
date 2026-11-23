# frozen_string_literal: true

# When librdkafka cannot build a message (here its headers) and the poll retries, Karafka should
# report it via `error.occurred` with the topic, partition and offset in the error details. The
# retry skips the message, but the user can seek back to it from the consumer and consume it.

setup_karafka(allow_errors: %w[connection.client.poll.error])

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

# The poll does not retry when the error lands at the end of the poll window. We force the retry
# so this scenario does not depend on timing
module ForcedRetry
  def retryable?
    if DT.key?(:broken) && !DT.key?(:retry_forced)
      DT[:retry_forced] = true

      return true
    end

    super
  end
end

Karafka::TimeTrackers::Poll.prepend(ForcedRetry)

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }

    return if DT.key?(:seeked)
    return if DT[:errors].empty?

    DT[:seeked] = true
    seek(DT[:errors].first[:error].details[:offset])
  end
end

draw_routes(Consumer)
produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:offsets].include?(2)
end

event = DT[:errors].first
error = event[:error]

assert_equal 1, DT[:errors].size
assert_equal "connection.client.poll.error", event[:type]
assert_equal :bad_msg, error.code
assert_equal DT.topic, error.details[:topic]
assert_equal 0, error.details[:partition]
assert_equal 2, error.details[:offset]
assert DT.key?(:seeked)
# Skipped first: offset 3 was consumed before offset 2
assert DT[:offsets].index(3) < DT[:offsets].index(2)
assert_equal [2, 3, 4], DT[:offsets].last(3)
