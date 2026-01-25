# frozen_string_literal: true

# When offset reset error occurs it should be immediately raised when user explicitly wanted an
# error to occur.

setup_karafka(allow_errors: %w[connection.client.poll.error]) do |config|
  config.kafka[:"auto.offset.reset"] = "error"
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:error] = event[:error]
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:messages] = messages
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT.key?(:error)
end

# No data should be consumed
assert DT[:messages].empty?
assert_equal DT[:error].code, :auto_offset_reset
