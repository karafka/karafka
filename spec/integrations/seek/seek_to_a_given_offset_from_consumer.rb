# frozen_string_literal: true

# Karafka should be able to easily consume from a given offset, instead of starting from 0.
# Karafka makes sure, we do not process in parallel incoming data from the same partition
# ahead, so we can easily rewind the offset and then the client queue will be cleared. What that
# means is that we do not have to worry beyond our current batch.
# It is worth keeping in mind, that in order for this to work, the current consumption process
# need to happen from the "previous" offset before seeking. Otherwise consumer instance won't
# be initialized

setup_karafka

elements = Array.new(20) { SecureRandom.uuid }
elements.each { |data| produce(DT.topic, data) }

class Consumer < Karafka::BaseConsumer
  def consume
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

draw_routes(Consumer)

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal elements[10..-1], DT[0]
