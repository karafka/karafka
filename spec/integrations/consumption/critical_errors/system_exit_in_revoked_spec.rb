# frozen_string_literal: true

# A process-critical error (SystemExit via `exit`) raised from `#revoked` is not rescued by the
# consumer (it rescues only StandardError there). It must reach the worker, be reported as
# `worker.process.error` and still trigger the graceful shutdown. The worker must survive it:
# the eager rebalance revokes all three partitions and with a single worker, the revocation jobs
# that follow the first `exit` can run only when the worker is still alive.

setup_karafka(allow_errors: %w[worker.process.error]) do |config|
  config.concurrency = 1
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << [event[:type], event[:error].class]
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << partition
  end

  def revoked
    DT[:revoked] << partition

    exit(1)
  end
end

draw_topics do
  topic DT.topic do
    partitions 3
  end
end

draw_routes do
  consumer_group DT.topic do
    topic DT.topic do
      consumer Consumer
    end
  end
end

DT.uuids(30).each { |data| produce(DT.topic, data, partition: rand(0..2)) }

consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(0.1) until DT[:consumed].uniq.size >= 3

  consumer.subscribe(DT.topic)
  consumer.poll(100) until DT.key?(:end)
end

# The stop is initiated by the framework, the wait block only observes
start_karafka_and_wait_until(reset_status: true) do
  !DT[:revoked].empty? && Karafka::App.done?
end

DT[:end] = true
other.join
consumer.close

assert_equal [["worker.process.error", SystemExit]], DT[:errors].uniq
assert_equal [0, 1, 2], DT[:revoked].sort
