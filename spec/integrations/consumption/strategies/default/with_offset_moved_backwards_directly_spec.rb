# frozen_string_literal: true

# While default marking in Karafka prevents marking backwards it can still be done by setting
# the `reset_offset` manually. This will allow us to mark in past.

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
      seek(0, reset_offset: true)

      break
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal 3, fetch_first_offset
