# frozen_string_literal: true

# When errors occur in partitioner, the partitioning should be reduced and the error should not
# leak out to the listener. Leaking could cause the total crash and critical recovery flow.

class Listener
  def on_error_occurred(event)
    DT[:errors] << event[:type]
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 2
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    DT[:b1] = true if DT[:offsets].size >= 10
  end
end

class Partitioner
  def call(_)
    return 0 unless DT.key?(:b1)
    return 0 if DT[:raised].size > 2

    DT[:raised] << true

    raise
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: Partitioner.new
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:offsets].size >= 20 && DT.key?(:b1) && DT[:raised].size > 2
end

assert_equal DT[:errors].uniq, %w[virtual_partitions.partitioner.error]

previous = -1
DT[:offsets].each do |offset|
  assert_equal offset, previous + 1

  previous = offset
end
