# frozen_string_literal: true

# Karafka should be able to easily consume from a given offset based on the time of the event and
# not the offset numeric value.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    if @after_seek
      # Process data only after the offset seek has been sent
      messages.each do |message|
        DT[message.metadata.partition] << message.raw_payload
      end
    else
      seek(DT[:starting_time])
      @after_seek = true
    end
  end
end

draw_routes(Consumer)

expected = []

DT.uuids(12).each_with_index do |uuid, index|
  DT[:starting_time] = Time.now if index == 10

  expected << uuid if DT.key?(:starting_time)

  produce(DT.topic, uuid)

  # Sleep between messages so we can go to a proper time
  sleep(0.5)
end

start_karafka_and_wait_until do
  DT[0].size >= 2
end

assert_equal expected, DT[0]
