# frozen_string_literal: true

# Fast jobs should also not have any problems (though not recommended) when running as lrj
# and they should behave the same way as once without throttling enabled

setup_karafka do |config|
  config.max_messages = 5
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.raw_payload
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    manual_offset_management true
    # Make sure never met
    throttling(limit: 1_000_000, interval: 100_000)
    virtual_partitions(
      partitioner: ->(_msg) { rand(9) }
    )
  end
end

payloads = DT.uuids(20)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

# Not deterministic due to VPs
assert_equal payloads.sort, DT[0].sort
assert_equal 0, fetch_first_offset
