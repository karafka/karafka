# frozen_string_literal: true

# When partition is lost but our job is still running, it should be allowed to finish work and
# should not run while code execution is still running.
# Revocation code should wait on the whole job to finish before running `#revoked`.
#
# @note This works differently in the Pro LRJ.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 1
  config.max_messages = 1_000
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:lost)

    DT[:run] << Time.now.to_f

    DT[:executed] << messages.metadata.partition

    sleep(15)

    DT[:run] << Time.now.to_f
  end

  def revoked
    DT[:revoked_at] = Time.now.to_f
    DT[:lost] = true
  end
end

produce_many(DT.topic, DT.uuids(10))

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  DT.key?(:lost)
end

assert !(DT[:run].last..DT[:run].first).cover?(DT[:revoked_at])
