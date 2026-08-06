# frozen_string_literal: true

# When running the fibers workers backend, producing messages from within fiber-hosted
# consumers (both sync and async) should work

setup_karafka do |config|
  config.workers.backend = :fibers
  config.workers.concurrency = 5
end

class SourceConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      producer.produce_sync(topic: DT.topics[1], payload: "sync-#{message.raw_payload}")
      producer.produce_async(topic: DT.topics[1], payload: "async-#{message.raw_payload}")
    end
  end
end

class TargetConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:received] << message.raw_payload }
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer SourceConsumer
  end

  topic DT.topics[1] do
    consumer TargetConsumer
  end
end

elements = DT.uuids(5)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[:received].uniq.size >= 10
end

elements.each do |element|
  assert DT[:received].include?("sync-#{element}")
  assert DT[:received].include?("async-#{element}")
end
