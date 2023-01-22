# frozen_string_literal: true

# While VPs do not support pausing in the regular flow, we can pause while running VP when
# collapsed. This can be used to provide a manual back-off if we would want.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[0] << [message.offset, collapsed?, Time.now.to_f] }

    if collapsed?
      pause(3, 10_000)
    elsif DT[:raised].empty?
      DT[:raised] << true
      raise StandardError
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

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[0].size >= 7
end

# We should have two messages next to each other in the flow that are distanced by at least 10
# seconds, which will be the equivalent of the pause.

previous = nil
distances = []

DT[0].each do |row|
  unless previous
    previous = row
    next
  end

  distances << row.last - previous.last

  previous = row
end

assert distances.max >= 10
