# frozen_string_literal: true

# If we seek to a long ago, before even topic was created, we should start from beginning on
# other partitions than 0 as well

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    return if partition.zero?

    if @after_seek
      # Process data only after the offset seek has been sent
      messages.each do |message|
        DT[message.metadata.partition] << message.raw_payload
      end
    else
      seek(Time.now - (60 * 5))
      @after_seek = true
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 2)
  end
end

elements = DT.uuids(20)

2.times do |i|
  produce_many(DT.topic, elements, partition: i)
end

start_karafka_and_wait_until do
  DT[1].size >= 10
end

assert_equal elements, DT[1]
