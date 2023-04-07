# frozen_string_literal: true

# We should be able to apply custom logic flow, when re-processing data after an error.

setup_karafka(allow_errors: true)

SuperException = Class.new(Exception)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise if message.offset == 5 && !retrying?

      DT[:offsets] << message.offset

      mark_as_consumed(message)
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:offsets].count >= 10
end

assert_equal DT[:offsets], (0..9).to_a
