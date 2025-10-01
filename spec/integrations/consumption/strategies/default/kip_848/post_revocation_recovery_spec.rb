# frozen_string_literal: true

# Karafka should recover from expired timeout when post-recovery the processing is fast enough

setup_karafka(allow_errors: %w[connection.client.poll.error]) do |config|
  # Use the new consumer protocol (KIP-848)
  config.kafka[:'group.protocol'] = 'consumer'
  # Remove settings that are not compatible with KIP-848
  config.kafka.delete(:'partition.assignment.strategy')
  config.kafka.delete(:'heartbeat.interval.ms')
  config.kafka.delete(:'session.timeout.ms')
  # Very short max poll interval for faster testing
  config.kafka[:'max.poll.interval.ms'] = 5_000
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
