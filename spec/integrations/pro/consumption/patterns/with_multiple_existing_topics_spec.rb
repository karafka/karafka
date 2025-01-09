# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should be able to match existing topics when regexp specifies all of them
# No rebalances should occur in between detections

setup_karafka do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end

  def revoked
    # Should not happen
    raise StandardError
  end
end

draw_routes do
  pattern(/(#{DT.topics[0]}|#{DT.topics[1]})/) do
    consumer Consumer
  end
end

produce_many(DT.topics[0], DT.uuids(1))
produce_many(DT.topics[1], DT.uuids(1))

start_karafka_and_wait_until do
  DT[0].size >= 2
end

# No assertions needed. If works, won't hang.
