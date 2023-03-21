# frozen_string_literal: true

# Karafka should be able to just process all the messages one after another

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    max_messages 1
    long_running_job true
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[0].size >= 5
end

assert DT[0].size >= 5
