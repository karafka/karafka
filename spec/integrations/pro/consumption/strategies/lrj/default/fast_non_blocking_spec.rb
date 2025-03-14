# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Fast jobs should also not have any problems (though not recommended) when running as lrj
# It should work ok also when used via `non_blocking` API.

setup_karafka do |config|
  config.max_messages = 1
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << messages.first.raw_payload
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    non_blocking true
  end
end

payloads = DT.uuids(20)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

assert_equal payloads, DT[0]
