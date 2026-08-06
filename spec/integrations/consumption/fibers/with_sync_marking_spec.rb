# frozen_string_literal: true

# When running the fibers workers backend, blocking sync offset commits (`mark_as_consumed!`)
# from within a fiber should work correctly. Such calls do not yield to the fiber scheduler
# (they block the whole carrier thread), but they must remain fully functional.

setup_karafka do |config|
  config.workers.backend = :fibers
  config.workers.concurrency = 5
end

class SyncMarkingConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed!(message)

      DT[:marked] << message.offset
    end
  end
end

class SleepingConsumer < Karafka::BaseConsumer
  def consume
    sleep(1)

    messages.each { |message| DT[:slept] << message.offset }
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer SyncMarkingConsumer
  end

  topic DT.topics[1] do
    consumer SleepingConsumer
  end
end

produce_many(DT.topics[0], DT.uuids(10))
produce_many(DT.topics[1], DT.uuids(1))

start_karafka_and_wait_until do
  DT[:marked].uniq.size >= 10 && DT[:slept].size >= 1
end

assert_equal (0..9).to_a, DT[:marked].uniq.sort

# The sync committed offset is stored in Kafka
assert_equal 10, fetch_next_offset(DT.topics[0])
