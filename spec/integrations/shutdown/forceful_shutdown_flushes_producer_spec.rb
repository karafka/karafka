# frozen_string_literal: true

require "securerandom"

# F02: On a forceful supervised shutdown (a job exceeds shutdown_timeout), Karafka calls
# `Kernel.exit!`, which terminates the process immediately and skips the `ensure` block that
# flushes/closes the producer. Async-buffered produced messages (DLQ `produce_async` copies, user
# `produce_async`) are then discarded even though consumer offsets were already committed.
#
# We reproduce it across the process boundary. The PARENT spawns a fresh, fully-supervised Karafka
# server (the F02_CHILD branch of this same file) that consumes a seed message, buffers an async
# copy and then hangs past shutdown_timeout - forcing the forceful `exit!`. The parent then verifies
# whether the async copy reached Kafka: with the fix it is flushed before `exit!` and present;
# without it, it is lost. A spawned process (rather than a fork) is used so the child runs a clean
# supervised server that actually reaches the forceful `exit!(forceful_exit_code)`.

SOURCE = ENV.fetch("F02_SOURCE") { DT.topic }
TARGET = "#{SOURCE}-buffered"

setup_karafka(allow_errors: true) do |config|
  config.shutdown_timeout = 2_000
  config.initial_offset = "earliest"
  # Keep the async copy buffered (not flushed by the linger timer) until the forceful exit, so the
  # discarded-buffer bug is actually exercised rather than masked by an early flush.
  config.kafka[:"queue.buffering.max.ms"] = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Buffer an async message (mirrors a DLQ produce_async copy), signal readiness, then hang so the
    # worker cannot finish within shutdown_timeout and the shutdown becomes forceful.
    Karafka.producer.produce_async(topic: TARGET, payload: "buffered-copy")
    DT[:buffered] << true
    sleep(60)
  end
end

draw_routes do
  topic SOURCE do
    consumer Consumer
  end
end

if ENV["F02_CHILD"]
  # Child server: once the async copy is buffered, request shutdown. The consumer is still hanging,
  # so the shutdown becomes forceful and (being supervised) calls Kernel.exit!(forceful_exit_code).
  start_karafka_and_wait_until { DT[:buffered].any? }

  # The forceful exit! runs from the wait_until background thread; block the main thread so it does
  # not end the script (and exit cleanly) before that exit! fires.
  sleep
else
  # Parent: create the target, seed the source (via a raw producer so we do not block on the 60s
  # linger configured on Karafka's producer), then spawn the child server and verify Kafka.
  Karafka::Admin.create_topic(TARGET, 1, 1)

  seed = Rdkafka::Config.new(
    "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092")
  ).producer
  seed.produce(topic: SOURCE, payload: "seed").wait
  seed.close

  pid = spawn(
    { "F02_CHILD" => "1", "F02_SOURCE" => SOURCE },
    "bundle exec ruby -r ./spec/integrations_helper.rb #{__FILE__}"
  )
  _, status = Process.wait2(pid)

  received = []
  consumer = setup_rdkafka_consumer("group.id": SecureRandom.uuid, "auto.offset.reset": "earliest")
  consumer.subscribe(TARGET)
  deadline = Time.now + 20
  while Time.now < deadline && received.empty?
    message = consumer.poll(1_000)
    received << message.payload if message
  end
  consumer.close

  # The child must have forcefully exited (code 2 == forceful_exit_code)
  assert_equal 2, status.exitstatus, "expected forceful exit code 2, got #{status.inspect}"

  # And the async-buffered copy must have been flushed before exit! (it is lost without the fix)
  assert_equal ["buffered-copy"], received
end
