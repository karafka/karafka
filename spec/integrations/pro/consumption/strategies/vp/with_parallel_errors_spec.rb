# frozen_string_literal: true

# When Karafka consumes in the VP mode and many errors happen in many of the processing units,
# we we should continue and we should restart the processing from the first offset on a batch in
# a collapsed mode until the collective offset is passed

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    if !@raised && messages.count > 1
      @raised = true
      raise StandardError
    end

    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(
        partitioner: ->(msg) { msg.raw_payload }
      )
    end
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert_equal 10, DT[:errors].size, DT[:errors].size

previous = nil

## Check that no messages are skipped
DT[0].flatten.sort.uniq.each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset

  previous = offset
end
