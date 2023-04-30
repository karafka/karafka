# frozen_string_literal: true

# When we continue to have an error on the same event in the collapse mode, others should be
# filtered for as long as the collapse lasts.

class Listener
  def on_error_occurred(_event)
    DT[:errors] << true
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    if collapsed?
      messages.each do |message|
        DT[1] << message.offset
      end

      raise if messages.map(&:offset).include?(10)
    else
      messages.each do |message|
        DT[0] << message.offset

        raise if message.offset == 10

        mark_as_consumed(message)
      end
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      manual_offset_management(true)
      consumer Consumer
      virtual_partitions(
        partitioner: ->(_) { rand(10) }
      )
    end
  end
end

produce_many(DT.topic, DT.uuids(50))

start_karafka_and_wait_until do
  DT[:errors].size >= 5
end

assert_equal([10], (DT[0].sort.uniq & DT[1].sort.uniq))
assert (DT[0] + DT[1]).count(10) >= 5
