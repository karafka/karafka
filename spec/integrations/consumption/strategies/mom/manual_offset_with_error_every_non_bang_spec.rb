# frozen_string_literal: true

# When manual offset management is on, upon error Karafka should start again from the place
# it had in the checkpoint. If we checkpoint after each message is processed (here adding to array)
# it should not have any duplicates as the error happens before checkpointing

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    @consumed ||= 0

    messages.each do |message|
      @consumed += 1

      raise StandardError if @consumed == 50

      DT[0] << message.raw_payload

      mark_as_consumed(message)
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert_equal elements, DT[0]
assert_equal 100, DT[0].size
assert_equal 1, DT.data.size
