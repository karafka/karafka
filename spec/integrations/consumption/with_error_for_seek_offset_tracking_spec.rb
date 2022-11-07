# frozen_string_literal: true

# Karafka should publish seek offset upon error so we know offset of message that failed
# @note This may be a bit more complex when doing batch processing operations

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset == 5

      mark_as_consumed(message)
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event.payload.key?(:seek_offset)

  DT[:seek_offsets] << event.payload[:seek_offset]
end

start_karafka_and_wait_until do
  !DT[:seek_offsets].empty?
end

assert_equal 5, DT[:seek_offsets].first, DT.data
