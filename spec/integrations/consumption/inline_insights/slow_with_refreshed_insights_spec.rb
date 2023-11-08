# frozen_string_literal: true

# Inline insights should auto-refresh when new values are present during extensive processing

setup_karafka do |config|
  config.internal.tick_interval = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do
      # Here just to check that alias works
      inline_insights?
      DT[:samples] << inline_insights
      sleep(2)
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    inline_insights(true)
  end
end

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:samples].size >= 5
end

# Make sure every sample is unique as they should change while processing happens
assert DT[:samples] == DT[:samples].uniq
