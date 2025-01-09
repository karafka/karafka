# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should be able to match existing topic with pattern when starting processing and given
# topic already exists

setup_karafka do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] = true
  end
end

draw_routes do
  pattern(/#{DT.topic}/) do
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(0)
end

# No assertions needed. If works, won't hang.
