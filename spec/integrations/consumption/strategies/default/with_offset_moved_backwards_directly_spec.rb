# frozen_string_literal: true

# Allow to mark in past.

setup_karafka do |config|
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed!(message)

      if @moved && message.offset == 2
        DT[:done] = true
        pause(0)
        return
      end

      next unless message.offset == 10 && !@moved

      @moved = true
      seek(0)

      break
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal 3, fetch_next_offset
