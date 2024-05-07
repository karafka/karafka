# frozen_string_literal: true

# We should be able to seek back and without reset it should not store the seeked offset

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    if @seeked && !@marked
      mark_as_consumed!(messages.first)
      @marked = true
      DT[:done] = true
    end

    return if @seeked

    messages.each do |message|
      mark_as_consumed!(message)

      next until message.offset == 9

      @seeked = true
      seek(1, reset_offset: false)

      return
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal 10, fetch_next_offset
