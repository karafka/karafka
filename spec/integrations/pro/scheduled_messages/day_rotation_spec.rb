# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When day ends, we should rotate it and move on
# Moving on should not trigger a second dispatch of already dispatched or cancelled events

setup_karafka

class MonitoringConsumer < Karafka::BaseConsumer
  def consume
    DT[:received_at] = Time.now
  end

  def tick
    return if @pinged

    @pinged = true
    sleep(5)
    DT[:created_at] = Time.now.to_i
    DT[:fence_time] = Time.now
    DT[:ended] = true
  end
end

draw_routes do
  scheduled_messages(DT.topics[0]) do |t1, t2|
    t1.config.partitions = 1
    t2.config.partitions = 1
  end

  topic DT.topics[1] do
    consumer MonitoringConsumer
    periodic(interval: 1_000)
  end
end

DT[:created_at] = (Time.now - (24 * 60 * 60)).to_i

# We patch it so we can simulate end of day
module Karafka
  module Pro
    module ScheduledMessages
      class Day
        def initialize
          @created_at = DT[:created_at]

          time = Time.at(@created_at)

          @starts_at = Time.utc(time.year, time.month, time.day).to_i
          @ends_at = @starts_at + 86_399
        end

        def ended?
          ended = DT.key?(:ended) && !DT.key?(:switched)

          DT[:switched] = true if ended

          ended
        end
      end
    end
  end
end

# Produce message that should be sent the "next" day (today)
message = {
  topic: DT.topics[1],
  key: '0',
  payload: 'payload'
}

Karafka.producer.produce_sync Karafka::Pro::ScheduledMessages.schedule(
  message: message,
  epoch: Time.now.to_i,
  envelope: { topic: DT.topics[0], partition: 0 }
)

start_karafka_and_wait_until do
  DT.key?(:received_at)
end

# Dispatch should not happen until we "replay" and load new day
assert DT[:received_at] > DT[:fence_time]
