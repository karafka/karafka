# frozen_string_literal: true

# We should be able to use `#failing?` to detect, that part of our work has already failed and
# that our current set of VPs will collapse.
#
# This can be used to stop processing when we know, it is going to be re-processed again

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 10
end

MUTEX = Mutex.new

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:registers] << true

    MUTEX.synchronize do
      return if DT[:registers].size == 1

      if DT[:raised].empty?
        DT[:raised] << true
        sleep(1)

        raise StandardError
      end
    end

    if failing?
      DT[:failing] << true

      return

    else
      DT[:ended] << true
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload.to_i % 10 }
    )
  end
end

produce_many(DT.topic, Array.new(100) { |i| i.to_s })

start_karafka_and_wait_until do
  DT[:failing].size >= 9
end

assert DT[:ended].empty?
