# frozen_string_literal: true

# If we never mark offsets, upon errors we should start from beginning

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset

      raise if message.offset == 50
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    virtual_partitions(
      partitioner: ->(_msg) { rand(9) }
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:offsets].count(0) >= 5
end
