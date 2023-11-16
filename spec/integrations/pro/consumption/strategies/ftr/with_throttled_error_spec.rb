# frozen_string_literal: true

# When we reach throttling limit and error, we should process again from the errored place

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    @batches ||= 0
    @batches += 1

    messages.each do |message|
      DT[0] << message.offset
    end

    return if @batches < 2

    DT[:started] = messages.first.offset unless DT.key?(:started)

    raise StandardError
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    throttling(
      limit: 5,
      interval: 5_000
    )
  end
end

elements = DT.uuids(100)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[0].size >= 50
end

started = DT[:started]

assert DT[0].count(started) > 1
# Should not move beyond the failing batch + throttling
assert DT[0].none? { |element| element > started + 5 }
