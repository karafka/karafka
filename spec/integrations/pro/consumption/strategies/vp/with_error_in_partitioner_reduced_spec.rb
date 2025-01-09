# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When errors occur in partitioner, it should reduce to one partition whole batch

class Listener
  def on_error_occurred(event)
    DT[:errors] << event[:type]
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 10
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumers] << object_id

    messages.each do |message|
      DT[:offsets] << message.offset
    end

    DT[:b1] = true if DT[:offsets].size >= 10
  end
end

class Partitioner
  def call(_)
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
  DT[:offsets].size >= 20 && DT.key?(:b1) && DT[:raised].size > 5
end

assert_equal DT[:consumers].uniq.size, 1
