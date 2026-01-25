# frozen_string_literal: true

# If we seek to the earliest, we should start from the beginning

setup_karafka do |config|
  config.initial_offset = "latest"
end

class Consumer < Karafka::BaseConsumer
  def consume
    if @after_seek
      # Process data only after the offset seek has been sent
      messages.each do |message|
        DT[message.metadata.partition] << message.raw_payload
      end
    else
      seek(:earliest)
      @after_seek = true
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(20)

Thread.new do
  sleep(10)
  produce_many(DT.topic, elements)
end

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal elements, DT[0]
