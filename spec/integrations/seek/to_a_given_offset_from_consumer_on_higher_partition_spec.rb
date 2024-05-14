# frozen_string_literal: true

# Karafka should be able to easily consume from a given offset, instead of starting from 0.
# Karafka makes sure, we do not process in parallel incoming data from the same partition
# ahead, so we can easily rewind the offset and then the client queue will be cleared. What that
# means is that we do not have to worry beyond our current batch.
# It is worth keeping in mind, that in order for this to work, the current consumption process
# need to happen from the "previous" offset before seeking. Otherwise consumer instance won't
# be initialized

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
      seek(10)
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

assert_equal elements[10..-1], DT[1]
