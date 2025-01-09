# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to reference both `#processing_lag` and `consumption_lag` even when we
# had delay and no data would be consumed prior.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def shutdown
    messages.metadata.processing_lag
    messages.metadata.consumption_lag
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    delay_by(100_000)
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  sleep(5)
end
