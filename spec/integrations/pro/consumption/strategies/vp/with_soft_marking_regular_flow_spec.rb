# frozen_string_literal: true

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 10
end



m = Karafka::Pro::Processing::OffsetManager.new


p m.register([0, 3, 4,5,9])
p m.register([0, 1, 2, 6, 7, 8])


m.mark_as_consumed(3)
m.mark_as_consumed(2)

p m.markable_offset




exit


class Consumer < Karafka::BaseConsumer
  def consume
    coordinator.synchronize do
      p coordinator.consumptions.values
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(50))

start_karafka_and_wait_until do
  DT[0].size >= 7
end
