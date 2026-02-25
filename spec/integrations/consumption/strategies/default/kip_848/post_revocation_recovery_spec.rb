# frozen_string_literal: true

# Karafka should recover from expired timeout when post-recovery the processing is fast enough

setup_karafka(
  allow_errors: %w[connection.client.poll.error],
  consumer_group_protocol: true
) do |config|
  # Remove session timeout and set very short max poll interval for faster testing
  config.kafka.delete(:"session.timeout.ms")
  config.kafka[:"max.poll.interval.ms"] = 5_000
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    if DT.key?(:ticked)
      DT[:done] = true

      return
    end

    DT[:ticked] = true

    sleep(10)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(2))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal DT[:offsets], [0, 0, 1]
