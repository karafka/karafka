# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should not have the insights methods when insights are not enabled
# In Pro despite extra option, should behave same as in OSS when no forced required

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

assert(DT[:stats].all?(-1))
assert(DT[:stats_exist].all?(-1))
