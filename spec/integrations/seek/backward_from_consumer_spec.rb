# frozen_string_literal: true

# This spec aims to test seeking process. We use seek to process first message out of all and then
# we move backwards till 0

setup_karafka

produce_many(DT.topic, DT.uuids(10))

class Consumer < Karafka::BaseConsumer
  def initialized
    @backwards = false
    @ignore = false
  end

  def consume
    return if @ignore

    if @backwards
      message = messages.first

      DT[messages.metadata.partition] << message.offset
      seek(message.offset - 1)

      @ignore = true if message.offset.zero?
    elsif messages.last.offset == 9
      @backwards = true
      seek(9)
    end
  end
end

draw_routes(Consumer, create_topics: false)

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal (0..9).to_a.reverse, DT[0]
