# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When processing messages with iterator enabled but no features enabled, it should work

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    each do |message|
      DT[:done] = message
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    adaptive_iterator(
      active: true,
      clean_after_yielding: false
    )
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT.key?(:done)
end
