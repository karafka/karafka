# frozen_string_literal: true

# When SIGTERM is sent while a consumer is actively processing messages,
# Karafka should shut down gracefully with offset tracking.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    DT[:consuming] << true
    sleep(2)
  end

  def shutdown
    DT[:shutdown] << true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(5))

Thread.new do
  sleep(0.1) until DT[:consuming].size.positive?

  Process.kill("TERM", Process.pid)
end

start_karafka_and_wait_until { false }

# Some messages should have been processed before shutdown
assert DT[:offsets].size >= 1
# Shutdown callback should have been invoked
assert_equal [true], DT[:shutdown]
