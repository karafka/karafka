# frozen_string_literal: true

# Karafka should not have the insights methods when insights are not enabled

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:stats] << intercept { statistics }
    DT[:stats] << intercept { insights }
    DT[:stats_exist] << intercept { statistics? }
    DT[:stats_exist] << intercept { insights? }
  end

  def intercept
    yield
  rescue NameError
    -1
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:stats) && DT.key?(:stats_exist)
end

assert(DT[:stats].all? { |val| val == -1 })
assert(DT[:stats_exist].all? { |val| val == -1 })
