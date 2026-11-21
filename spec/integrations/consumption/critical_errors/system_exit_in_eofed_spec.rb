# frozen_string_literal: true

# A process-critical error (SystemExit via `exit`) raised from `#eofed` is not rescued by the
# consumer (it rescues only StandardError there). It must reach the worker, be reported as
# `worker.process.error` and still trigger the graceful shutdown. The worker must survive it:
# with a single worker, the shutdown job can run only when the worker is still alive.

setup_karafka(allow_errors: %w[worker.process.error]) do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.concurrency = 1
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << [event[:type], event[:error].class]
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << messages.size
  end

  def eofed
    DT[:eofed] = true

    exit(1)
  end

  def shutdown
    DT[:shutdown] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    eofed true
  end
end

produce_many(DT.topic, DT.uuids(2))

start_karafka_and_wait_until(reset_status: true) do
  DT.key?(:eofed) && Karafka::App.done?
end

assert_equal [["worker.process.error", SystemExit]], DT[:errors].uniq
assert DT.key?(:shutdown)
