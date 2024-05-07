# frozen_string_literal: true

# If we seek to a long ago, before even topic was created, we should start from beginning

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    if @after_seek
      # Process data only after the offset seek has been sent
      messages.each do |message|
        DT[message.metadata.partition] << message.raw_payload
      end
    else
      seek(Time.now - 60 * 5)
      @after_seek = true
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal elements, DT[0]
