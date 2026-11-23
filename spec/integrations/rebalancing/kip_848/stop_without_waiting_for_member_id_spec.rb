# frozen_string_literal: true

# Karafka should stop a KIP-848 consumer with an assignment without waiting for librdkafka to
# clear its member id. This protocol keeps its client-generated member id after the leave, so
# such a wait would last until `shutdown_timeout * 0.5` for each subscription group.

SHUTDOWN_TIMEOUT_MS = 60_000

setup_karafka(consumer_group_protocol: true) do |config|
  config.shutdown_timeout = SHUTDOWN_TIMEOUT_MS
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] = true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  next false unless DT.key?(:consumed)

  DT[:stopping_at] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  true
end

stop_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - DT[:stopping_at]

assert stop_time < SHUTDOWN_TIMEOUT_MS / 6_000.0
