# frozen_string_literal: true

# When a message goes to the DLQ, only its W3C trace headers (traceparent and tracestate)
# should be copied to the DLQ message. Other headers should not be copied and a message
# without trace headers should go to the DLQ without headers.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:headers] << message.headers
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

TRACEPARENT = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
TRACESTATE = "rojo=00f067aa0ba902b7"

produce(
  DT.topic,
  "1",
  headers: { "traceparent" => TRACEPARENT, "tracestate" => TRACESTATE, "other" => "value" }
)
produce(DT.topic, "2", headers: { "traceparent" => TRACEPARENT })
produce(DT.topic, "3", headers: { "other" => "value" })
produce(DT.topic, "4")

start_karafka_and_wait_until do
  DT[:headers].size >= 4
end

assert_equal(
  { "traceparent" => TRACEPARENT, "tracestate" => TRACESTATE },
  DT[:headers][0]
)
assert_equal({ "traceparent" => TRACEPARENT }, DT[:headers][1])
assert_equal({}, DT[:headers][2])
assert_equal({}, DT[:headers][3])
