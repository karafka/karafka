# frozen_string_literal: true

# When a job is marked as lrj, it should keep running longer than max poll interval and all
# should be good. It should continue processing after resume and should pick up next messages.
# Expired throttling should just seek correctly as expected and allow us to move on

setup_karafka do |config|
  config.max_messages = 2
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    @encounter ||= 0

    sleep(11 + @encounter)

    @encounter += 2

    DT[0] << messages.first.raw_payload
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
      manual_offset_management true
      throttling(limit: 1, interval: 11_100)
    end
  end
end

payloads = DT.uuids(4)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].size >= 4
end

assert_equal payloads, DT[0]
assert_equal 0, fetch_first_offset
