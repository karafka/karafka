# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When given partition is lost involuntary, we still should have last info
# In Pro despite extra option, should behave same as in OSS when no forced required

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 1
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Make sure we have insights at all
    return pause(messages.first.offset, 1_000) unless insights?

    DT[:running] << true
    DT[0] << insights?
    sleep(15)
    DT[0] << insights?
  end

  def revoked
    DT[:revoked] = true
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    inline_insights(true)
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[0].size >= 2 && DT.key?(:revoked)
end

assert DT[0].all?
